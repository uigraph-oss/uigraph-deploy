# UiGraph on EKS — Operations

Day-2 reference for the Terraform in this directory. Start with [`README.md`](README.md) if
you're new here; this doc is for whoever actually runs `terraform apply`.

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

## Exposure: internal vs. public

`exposure_mode = "internal"` (default): an internal ALB, reachable only inside the VPC, over VPN,
or via peering — no internet exposure.

`exposure_mode = "public"`: an internet-facing ALB. The chart is domain-centric throughout (OAuth
redirects, public URLs, host-based Ingress routing), so a few things follow from that:

- **A `domain_name` is always required** — it doesn't need to be public or owned by anyone in
  particular for an internal test, just a value the chart can build `app.<domain>` /
  `sync.<domain>` / `mcp.<domain>` from.
- **DNS in Route53?** Set `route53_zone_id` and Terraform automates the ACM cert request, DNS
  validation, and all three CNAME records. Works for an internal ALB too — a public DNS name
  resolving to a private IP is normal, and it simply won't be reachable from outside the VPC/VPN.
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

## Billing: connecting additional AWS accounts

Settings → Cloud Connections isn't limited to one account — connect as many as you like, each
with its own Role ARN + External ID. `billing_role_arn`/`billing_external_id` (`terraform output`)
only cover the one account `platform/` was applied into, because that's the only account this
Terraform has credentials for. For every other account — a second account the same org owns, or a
separate customer org's account entirely — that account's owner creates the equivalent role
themselves, trusting this deployment's `irsa_role_arn` output:

```bash
EXTERNAL_ID="<pick a random string, e.g. openssl rand -hex 16>"
IRSA_ROLE_ARN="<this deployment's terraform output irsa_role_arn>"

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$IRSA_ROLE_ARN" },
    "Action": "sts:AssumeRole",
    "Condition": { "StringEquals": { "sts:ExternalId": "$EXTERNAL_ID" } }
  }]
}
EOF

aws iam create-role --role-name uigraph-billing-read --assume-role-policy-document file://trust-policy.json

cat > permissions.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CostExplorerReadOnly",
      "Effect": "Allow",
      "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast", "ce:GetUsageForecast", "ce:GetDimensionValues", "ce:GetTags", "ce:GetCostCategories", "ce:ListCostCategoryDefinitions"],
      "Resource": "*"
    },
    {
      "Sid": "BudgetsReadOnly",
      "Effect": "Allow",
      "Action": ["budgets:ViewBudget", "budgets:DescribeBudgets", "budgets:DescribeBudgetPerformanceHistory"],
      "Resource": "*"
    },
    {
      "Sid": "ResourceDiscoveryReadOnly",
      "Effect": "Allow",
      "Action": "tag:GetResources",
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy --role-name uigraph-billing-read --policy-name uigraph-billing-read --policy-document file://permissions.json
```

Then connect it from Settings → Cloud Connections using that role's ARN and the External ID
picked above — same flow, same dialog, just pointed at a role in their own account.

Cost Explorer itself needs a one-time, account-wide enable in the Billing console (**Billing →
Cost Explorer → Enable**) — no Terraform resource covers that.

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
`platform/` applies it as a real Helm upgrade — the Helm provider is configured with
`experiments.manifest = true` specifically so it detects changes to the chart's own files, not
just to the `helm_release` resource's arguments.

Pod annotations carry a checksum of the chart's ConfigMap and of the Terraform-managed Secret, so
a config- or secret-only change (no image bump) still rolls pods — Kubernetes doesn't do that
automatically for env vars sourced from a ConfigMap/Secret.

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
- **`terraform apply` fails with "Kubernetes cluster unreachable: the server has asked for the
  client to provide credentials"**: the EKS auth token in a saved plan (`-out=...`) expired —
  tokens are valid ~15 minutes, and a saved plan reuses the token from when it was generated. Run
  `terraform apply` fresh (no `-out`) instead of reusing an old plan file.
- **A ConfigMap/Secret change lands but pods don't reflect it**: check the pod's
  `checksum/config`/`checksum/secret` annotations actually changed
  (`kubectl get pod <pod> -o jsonpath='{.metadata.annotations}'`). If they didn't, the apply
  didn't actually change the underlying values — the Kubernetes provider has been observed to
  silently drop an in-place update to a `kubernetes_secret`'s `data` map for some field
  combinations; `terraform apply -replace='kubernetes_secret.uigraph[0]'` forces a clean rewrite.

See [`../k8s/README.md`](../k8s/README.md) for more (OAuth redirect matching, Redis TLS/AUTH,
backup/restore) — this tree deploys the same [`../k8s/helm/uigraph`](../k8s/helm/uigraph) chart.
