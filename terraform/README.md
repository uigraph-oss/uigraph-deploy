# UiGraph on EKS

Terraform for running UiGraph on Kubernetes: API, GraphQL, gateway, UI, and MCP each as their own
autoscaling Deployment, backed by RDS, ElastiCache, and S3 in place of the bundled
Postgres/Redis/MinIO in the root [`docker-compose.yml`](../docker-compose.yml). No static AWS
credentials — every service authenticates via its pod's IAM role.

```
terraform/
├── cluster/    # optional — only if you don't already have an EKS cluster
└── platform/   # data plane (RDS/ElastiCache/S3/IAM) + the app itself
```

`cluster/` and `platform/` are independent Terraform states, each fully apply/destroy-able on its
own. `platform/` always targets a cluster that already exists — either one `cluster/` just built,
or one you already run — which keeps its Kubernetes/Helm providers on stable ground during both
`apply` and `destroy`.

## Which folder(s) do I run?

- **Already on EKS?** Skip `cluster/`. Point `platform/` at your cluster's VPC ID, subnet IDs,
  OIDC provider, and node security group.
- **Starting from nothing?** Run `cluster/` first, then `platform/` against its outputs.

## Configuration reference

| Concern | Variable | Where |
|---|---|---|
| New VPC, or an existing one | `create_vpc` | `cluster/` |
| New EKS cluster, or an existing one | (run `cluster/`, or don't) | `cluster/` |
| Kubernetes API server public or private | `cluster_endpoint_public_access` | `cluster/` |
| Additional cluster admins (IAM users/roles) | `additional_admin_principal_arns` | `cluster/` |
| App public or internal-only | `exposure_mode` (`"internal"` \| `"public"`) | `platform/` |
| HTTPS cert + DNS | `route53_zone_id` / `acm_certificate_arn` | `platform/` |
| Cost Explorer access for the service-costs feature | `enable_cost_explorer_access` | `platform/` |
| Terraform manages the Helm release, or you do | `manage_helm_release` | `platform/` |
| Image tags, replica counts, resources, anything else | `helm_values_override` | `platform/` |

Full reference: each variable's description in its `variables.tf`.

## Quick start — from scratch

```bash
cd terraform/cluster
cp terraform.tfvars.example terraform.tfvars   # aws_region, aws_profile, name_prefix
terraform init && terraform apply              # ~15-20 min

terraform output   # vpc_id, private_subnet_ids, public_subnet_ids, oidc_provider_arn,
                    # oidc_provider_url, node_security_group_id, cluster_name

cd ../platform
cp terraform.tfvars.new-cluster.example terraform.tfvars
# paste in the cluster/ outputs above; set domain_name and exposure_mode
terraform init && terraform apply              # ~10-15 min

terraform output app_url
```

Point kubectl at the cluster: `terraform -chdir=cluster output -raw configure_kubectl | bash`.

## Quick start — existing EKS cluster

```bash
cd terraform/platform
cp terraform.tfvars.example terraform.tfvars
# cluster_name, vpc_id, private_subnet_ids, oidc_provider_arn/url,
# node_security_group_id, domain_name
terraform init && terraform apply
```

If IRSA has never been used on this cluster, associate the OIDC provider once:

```bash
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
eksctl utils associate-iam-oidc-provider --cluster <cluster-name> --approve
```

If the cluster doesn't run `metrics-server`, install it — the chart's HPAs need it to read pod
CPU. `cluster/` installs it automatically when it builds the cluster.

## Storage credentials: IRSA, no static keys

The app authenticates to S3 entirely through its pod's IAM role — no access keys are created,
stored, or rotated. `platform/` annotates the shared ServiceAccount with an IRSA role scoped to
just the app's S3 bucket; `uigraph-api` and `uigraph-gateway` both resolve it automatically via
the AWS credential chain (`AWS_ROLE_ARN` / `AWS_WEB_IDENTITY_TOKEN_FILE`, injected by EKS).

If you're pointing the chart at a non-AWS S3-compatible endpoint (MinIO, on-prem), IRSA doesn't
apply there — set `STORAGE_ACCESS_KEY`/`STORAGE_SECRET_KEY` directly via `helm_values_override`
in that case.

## Exposure: internal vs. public

`exposure_mode = "internal"` (default): an internal ALB, reachable only inside the VPC, over VPN,
or via peering — no internet exposure.

`exposure_mode = "public"`: an internet-facing ALB. The chart is domain-centric throughout (OAuth
redirects, public URLs, host-based Ingress routing), so a few things follow from that:

- **A `domain_name` is always required** — it doesn't need to be public or owned by anyone in
  particular for an internal test, just a value the chart can build `app.<domain>` /
  `sync.<domain>` / `mcp.<domain>` from.
- **DNS in Route53?** Set `route53_zone_id` and Terraform automates the ACM cert, DNS validation,
  and all three CNAME records. Works for an internal ALB too — a public DNS name resolving to a
  private IP is normal, and it simply won't be reachable from outside the VPC/VPN.
- **DNS elsewhere?** Pass your own `acm_certificate_arn` and create the CNAMEs yourself
  (`terraform output alb_hostname`), or leave both unset for plain HTTP.
- **Switching `exposure_mode`** replaces the ALB rather than reconfiguring it in place — expect a
  few minutes of DNS propagation for the new hostname.

`cluster_endpoint_public_access` (in `cluster/`) is a separate concern: whether the Kubernetes API
server itself is internet-reachable. VPN-only environments should set both this and
`exposure_mode` accordingly.

## Cluster access (kubectl / AWS console)

AWS account permissions and Kubernetes access to a specific cluster are different systems. Only
the principal that ran `terraform apply` in `cluster/` gets cluster-admin automatically —
everyone else, including a full AWS account admin, sees "Unauthorized" until granted access
explicitly.

Add other admins in `cluster/terraform.tfvars`:

```hcl
additional_admin_principal_arns = [
  "arn:aws:iam::<account-id>:role/<some-admin-role>",
]
```

For AWS IAM Identity Center (SSO), this needs the permission set's underlying role ARN, not the
console session's assumed-role ARN:

```bash
aws iam list-roles --query "Roles[?contains(RoleName, '<permission set name>')].Arn" --output text
```

To grant access without adding an account-specific ARN to version-controlled Terraform:

```bash
aws eks create-access-entry --cluster-name <cluster-name> --principal-arn <role-arn>
aws eks associate-access-policy --cluster-name <cluster-name> --principal-arn <role-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

## Billing / cost visibility

`enable_cost_explorer_access = true` (default) grants the app's IRSA role read-only Cost Explorer
and Budgets access, for the in-app service-costs feature. Cost Explorer itself still needs a
one-time, account-wide enable in the Billing console (**Billing → Cost Explorer → Enable**) — no
Terraform resource covers that.

## Secrets

Default (`secret_management = "terraform"`): Terraform generates the DB password, app secret key,
and admin password, writing them into a Kubernetes Secret. This is what makes single-command
create/destroy possible; those values live in Terraform state as a result, so use a remote
encrypted backend if that matters for your environment.

For a hardened setup, `secret_management = "external-secrets"` sends RDS's master password to
Secrets Manager only (never Terraform state), and you wire up External Secrets Operator yourself
— see [`../k8s/README.md`](../k8s/README.md)'s ExternalSecret example. Point
`external_secret_name` at the Secret you manage.

## Upgrading

Bump image tags or any other chart setting by editing
[`../k8s/helm/uigraph/values.yaml`](../k8s/helm/uigraph/values.yaml)'s defaults, or by setting
`helm_values_override` for a deployment-specific change. Either way, `terraform apply` in
`platform/` applies it as a real Helm upgrade.

## Cost estimate (default sizing)

All-in, roughly: EKS control plane $0.10/hr + 2× `t3.medium` nodes ~$0.08/hr + NAT gateway
~$0.045/hr + RDS `db.t4g.micro` ~$0.016/hr + ElastiCache `cache.t4g.micro` ~$0.016/hr ≈
**$0.30-0.40/hr** (~$220-290/mo continuous). `single_nat_gateway = true` and the `t4g.micro`/
`t3.medium` defaults are the low end; multi-AZ NAT, larger instances, or `db_multi_az = true`
raise this.

## Tear down

`platform` first, then `cluster` if you created one:

```bash
cd terraform/platform && terraform destroy   # destroys RDS/ElastiCache/S3 — snapshot first if needed
cd ../cluster && terraform destroy           # only if cluster/ was used
```

`db_deletion_protection` and `db_skip_final_snapshot` (`platform/`) control how hands-off this is
— safe-but-manual by default; the dev tfvars example flips both for unattended teardown in test
environments.

## Troubleshooting

- **`platform apply` fails resolving `data.aws_eks_cluster`**: `cluster_name` doesn't exist in
  `aws_region`/`aws_profile`. If `cluster/` just ran, confirm its apply finished and
  `terraform -chdir=cluster output cluster_name` matches.
- **ALB never provisions / Ingress has no address**: check the AWS Load Balancer Controller's logs
  (`kubectl logs -n kube-system deploy/aws-load-balancer-controller`).
- **Route53 record creation fails on first apply**: the ALB hasn't finished provisioning when
  Terraform reads its hostname. Wait for `kubectl get ingress` to show an ADDRESS, then re-run
  `terraform apply` — idempotent.
- **502/504 from the ALB**: target group health checks are failing — check `kubectl get pods` /
  `kubectl logs` for the relevant service.
- **`uigraph-api` CrashLoopBackOff**: almost always the Postgres connection — check
  `postgres_endpoint` against the RDS security group allowing ingress from `node_security_group_id`.
- **A pod is OOMKilled**: raise `resources.limits.memory` via `helm_values_override`.
- **"Unauthorized" despite AWS admin permissions**: see "Cluster access" above.

See [`../k8s/README.md`](../k8s/README.md) for more (OAuth redirect matching, Redis TLS/AUTH,
backup/restore) — this tree deploys the same [`../k8s/helm/uigraph`](../k8s/helm/uigraph) chart.
