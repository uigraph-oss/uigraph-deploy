variable "aws_region" {
  description = "AWS region to create the cluster in."
  type        = string
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use (e.g. from ~/.aws/credentials). Leave null to use the default credential chain (env vars, instance role, SSO, etc.)."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to all resource names (e.g. \"uigraph-prod\"). Also used as the cluster name (\"<name_prefix>-eks\")."
  type        = string
  default     = "uigraph"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default     = {}
}

# --- Networking ---

variable "create_vpc" {
  description = "Create a new VPC for the cluster. Set false to place the cluster into a VPC you already have (fill in existing_vpc_id / existing_private_subnet_ids / existing_public_subnet_ids instead)."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC. Only used when create_vpc = true."
  type        = string
  default     = "10.50.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets/node group across. Only used when create_vpc = true. Leave null to auto-pick the first az_count AZs in aws_region."
  type        = list(string)
  default     = null
}

variable "az_count" {
  description = "Number of AZs to use when azs is left null. Needs at least 2."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ. Cheaper and fine for dev/test; set false for HA production."
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "VPC ID to deploy into when create_vpc = false."
  type        = string
  default     = null
}

variable "existing_private_subnet_ids" {
  description = "Private subnet IDs to place the node group into when create_vpc = false. Needs at least 2, in different AZs."
  type        = list(string)
  default     = []
}

variable "existing_public_subnet_ids" {
  description = "Public subnet IDs when create_vpc = false. Only needed if platform/ will run with exposure_mode = \"public\" (an internet-facing ALB needs public subnets)."
  type        = list(string)
  default     = []
}

# --- EKS ---

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.36"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from the public internet. Set false for VPN-only/fully private companies — you'll then need VPN/bastion/Direct Connect access into the VPC to run kubectl/helm/terraform against the cluster."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint, when cluster_endpoint_public_access = true."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_admin_principal_arns" {
  description = "Extra IAM principal ARNs (IAM users, or roles — e.g. an SSO permission set's role, not the assumed-role session ARN) to grant full cluster-admin Kubernetes access, beyond whichever principal ran `terraform apply` (that one already gets in via enable_cluster_creator_admin_permissions). Needed because AWS account admin permissions don't by themselves grant kubectl/console access to a specific cluster's resources — that's separate EKS access-entry/Kubernetes RBAC wiring."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}
