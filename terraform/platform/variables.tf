variable "aws_region" {
  description = "AWS region the cluster and data-plane resources live in."
  type        = string
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. Leave null to use the default credential chain."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to all resource names (e.g. \"uigraph-prod\")."
  type        = string
  default     = "uigraph"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default     = {}
}

# --- Cluster wiring — from cluster/'s outputs if you used it, or your own existing cluster ---

variable "cluster_name" {
  description = "Name of the (already existing) EKS cluster to deploy into."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID of the cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (in the cluster's VPC) to place RDS/ElastiCache into. Needs at least 2, in different AZs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs. Only required when exposure_mode = \"public\" (an internet-facing ALB needs public subnets)."
  type        = list(string)
  default     = []
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (aws eks describe-cluster ... | oidc.issuer), used for IRSA trust policies. If the cluster wasn't created by cluster/ and never had IRSA used before, associate it first: eksctl utils associate-iam-oidc-provider --cluster <name> --approve"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL of the cluster, without the leading \"https://\" (e.g. oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXX)."
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID shared by EKS worker nodes/pods, used to authorize RDS/ElastiCache ingress from the cluster."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace the app is installed into. Used for the IRSA trust policy condition, the generated Secret, and the Helm release."
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "Name of the ServiceAccount the Helm chart creates. Must match serviceAccount.name in helm_values_override if you set one there — by default the chart names it after helm_release_name, so this should normally equal helm_release_name."
  type        = string
  default     = "uigraph"
}

# --- RDS (Postgres) ---

variable "db_engine_version" {
  type    = string
  default = "16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "uigraph"
}

variable "db_username" {
  type    = string
  default = "uigraph"
}

variable "db_multi_az" {
  description = "Run RDS Multi-AZ for failover."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "RDS deletion protection. Leave true for anything you care about; set false in a throwaway/test environment so `terraform destroy` doesn't need a manual console step first."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip RDS's final snapshot on destroy. Leave false for anything you care about; true makes `terraform destroy` faster and fully hands-off for test environments."
  type        = bool
  default     = false
}

# --- ElastiCache (Redis) ---

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "redis_num_cache_clusters" {
  description = "Number of nodes in the replication group (1 primary + N-1 replicas)."
  type        = number
  default     = 1
}

variable "redis_auth_token_enabled" {
  description = "Enable Redis AUTH. Transit encryption is always on in this module (required for AUTH), and the chart's redis.tls is always set to match."
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Redis AUTH token, 16-128 characters. Required when redis_auth_token_enabled = true."
  type        = string
  default     = null
  sensitive   = true
}

# --- S3 ---

variable "bucket_name" {
  description = "S3 bucket name for UiGraph object storage. Must be globally unique. Leave null to auto-generate one (\"<name_prefix>-<random suffix>\") so a first run never collides with someone else's bucket."
  type        = string
  default     = null
}

variable "additional_cors_origins" {
  description = "Extra origins allowed to upload/download objects directly (the browser talks to S3 straight from presigned URLs, not through the backend). https://app.<domain_name> and its http:// variant are always allowed; add to this if you override app.publicUrl via helm_values_override to something else."
  type        = list(string)
  default     = []
}

# --- Billing / cost visibility ---

variable "enable_cost_explorer_access" {
  description = "Attach a read-only Cost Explorer + Budgets IAM policy to the app's IRSA role, for the in-app service-costs feature. Cost Explorer itself must also be enabled once, account-wide, via the Billing console — there's no Terraform resource for that account-level opt-in."
  type        = bool
  default     = true
}

# --- AWS Load Balancer Controller ---

variable "install_alb_controller" {
  description = "Install the AWS Load Balancer Controller via Helm (needed for the app's Ingress to provision an ALB). Set false if your existing cluster already has it installed."
  type        = bool
  default     = true
}

variable "alb_controller_chart_version" {
  type    = string
  default = "1.8.1"
}

# --- Exposure ---

variable "exposure_mode" {
  description = "\"internal\": ALB is only reachable inside the VPC/over VPN/peering — for companies that want this purely internal. \"public\": internet-facing ALB — for a publicly viewable UI."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["internal", "public"], var.exposure_mode)
    error_message = "exposure_mode must be \"internal\" or \"public\"."
  }
}

variable "domain_name" {
  description = "Base domain the app is served on. The chart derives app.<domain_name> (UI) and sync.<domain_name> (gateway/CLI sync) from this. Required even for a quick internal look — see terraform/README.md for the no-DNS-yet option (a temporary /etc/hosts entry)."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain_name. When set, ACM cert issuance/validation and the app./sync. DNS records are fully automated. Leave null to supply your own acm_certificate_arn (or none at all, for plain HTTP) and point DNS at the ALB hostname yourself after apply."
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN to use for the ALB's HTTPS listener, when route53_zone_id is null. Leave null (and route53_zone_id null) for a plain HTTP-only ALB — fine for a first look, not for anything real."
  type        = string
  default     = null
}

# A `check` block (not a `variable`-scoped `validation`) since this needs to reference two
# separate variables together — cross-variable `validation` conditions need Terraform >= 1.9,
# and this repo targets >= 1.5.
check "exposure_cert_config" {
  assert {
    condition     = !(var.acm_certificate_arn != null && var.route53_zone_id != null)
    error_message = "Set at most one of acm_certificate_arn or route53_zone_id — route53_zone_id provisions its own certificate."
  }
}

# --- Secrets ---

variable "secret_management" {
  description = "\"terraform\": Terraform generates the DB/admin/secret-key passwords and writes them straight into a Kubernetes Secret — simplest, one-command create/destroy, at the cost of those values living in Terraform state (use a remote encrypted backend). \"external-secrets\": RDS's master password goes to Secrets Manager only (manage_master_user_password, never in state); you wire up External Secrets Operator yourself, same pattern as k8s/README.md. Terraform then does not create the app's Secret or the RDS/admin/secret-key random_passwords."
  type        = string
  default     = "terraform"

  validation {
    condition     = contains(["terraform", "external-secrets"], var.secret_management)
    error_message = "secret_management must be \"terraform\" or \"external-secrets\"."
  }
}

variable "external_secret_name" {
  description = "Name of the externally-managed Kubernetes Secret to reference (secrets.existingSecret) when secret_management = \"external-secrets\"."
  type        = string
  default     = null
}

variable "admin_email" {
  description = "Admin login email. Leave null to default to admin@<domain_name>."
  type        = string
  default     = null
}

variable "admin_password" {
  description = "Admin login password, when secret_management = \"terraform\". Leave null to generate a random one (read it back afterward: terraform output -raw admin_password)."
  type        = string
  default     = null
  sensitive   = true
}

variable "figma_client_id" {
  type    = string
  default = ""
}

variable "figma_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

# --- AI chat (uigraph-gateway) ---

variable "ai_provider_api_key" {
  description = "API key for the AI chat feature's provider. Stored in SSM Parameter Store (SecureString) and in the app's Kubernetes Secret. Leave null to disable AI chat entirely."
  type        = string
  default     = null
  sensitive   = true
}

variable "ai_provider_npm" {
  description = "AI SDK provider package uigraph-gateway loads (e.g. \"@ai-sdk/openai\", \"@ai-sdk/openai-compatible\", \"@ai-sdk/anthropic\", \"@ai-sdk/amazon-bedrock\")."
  type        = string
  default     = "@ai-sdk/openai-compatible"
}

variable "ai_provider_model" {
  description = "Model name for chat responses. Required for the chat feature to actually work, even though it's not enforced at the infrastructure level."
  type        = string
  default     = null
}

variable "ai_provider_title_model" {
  description = "Model name for auto-generating conversation titles. Falls back to ai_provider_model when unset."
  type        = string
  default     = null
}

# --- App / Helm ---

variable "manage_helm_release" {
  description = "Let Terraform install/upgrade/uninstall the Helm release too, so one apply/destroy covers the whole stack. Set false to only provision AWS resources and handle Helm yourself (outputs.tf still prints every value a manual `helm install` needs)."
  type        = bool
  default     = true
}

variable "helm_chart_path" {
  description = "Path to the uigraph Helm chart. Defaults to this repo's own k8s/helm/uigraph — override if you've forked or vendored it elsewhere."
  type        = string
  default     = "../../k8s/helm/uigraph"
}

variable "helm_release_name" {
  type    = string
  default = "uigraph"
}

variable "helm_values_override" {
  description = "Free-form values merged on top of this root's own computed Helm values (postgres/redis/storage wiring, ingress, IRSA annotation) — e.g. image tags, replica counts, resource requests. Merged the same way `-f` merges multiple values files: deep, with these values winning on conflicting keys. See k8s/helm/uigraph/values.yaml for every available key."
  type        = any
  default     = {}
}
