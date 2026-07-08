variable "aws_region" {
  description = "AWS region to deploy the data-plane resources into."
  type        = string
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

# --- Existing cluster/network inputs (this module does not create a VPC or EKS cluster) ---

variable "vpc_id" {
  description = "VPC ID of the existing EKS cluster."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs (in the existing VPC) to place RDS and ElastiCache into. Needs at least 2 subnets in different AZs."
  type        = list(string)
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the existing EKS cluster's IAM OIDC provider (aws eks describe-cluster ... | oidc.issuer), used for the IRSA trust policy."
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "OIDC issuer URL of the existing EKS cluster, without the leading \"https://\" (e.g. oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXX)."
  type        = string
}

variable "eks_node_security_group_id" {
  description = "Security group ID shared by EKS worker nodes / pods, used to authorize RDS and ElastiCache ingress from the cluster."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace the Helm release is installed into. Used in the IRSA trust policy condition."
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "Name of the ServiceAccount the Helm chart creates (serviceAccount.name, or the chart's fullname if left default). Used in the IRSA trust policy condition."
  type        = string
  default     = "uigraph"
}

# --- RDS (Postgres) ---

variable "db_engine_version" {
  description = "Postgres engine version."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Postgres database name."
  type        = string
  default     = "uigraph"
}

variable "db_username" {
  description = "Postgres master username."
  type        = string
  default     = "uigraph"
}

variable "db_multi_az" {
  description = "Whether to run RDS Multi-AZ for failover."
  type        = bool
  default     = false
}

# --- ElastiCache (Redis) ---

variable "redis_engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_num_cache_clusters" {
  description = "Number of nodes in the Redis replication group (1 primary + N-1 replicas)."
  type        = number
  default     = 1
}

variable "redis_auth_token_enabled" {
  description = "Enable Redis AUTH (requires transit_encryption_enabled, which this module always sets). Corresponds to the chart's redis.authEnabled + redis.tls values."
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Redis AUTH token. Required if redis_auth_token_enabled is true. Must be 16-128 characters."
  type        = string
  default     = null
  sensitive   = true
}

# --- S3 ---

variable "bucket_name" {
  description = "S3 bucket name for UiGraph object storage. Must be globally unique."
  type        = string
}
