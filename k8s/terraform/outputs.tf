output "postgres_endpoint" {
  description = "RDS endpoint (host:port). Feed the host into the chart's postgres.host value."
  value       = aws_db_instance.uigraph.address
}

output "postgres_port" {
  value = aws_db_instance.uigraph.port
}

output "postgres_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the generated RDS master password (manage_master_user_password). Sync the SecretString's `password` field into the chart's Secret under secrets.keys.postgresPassword."
  value       = aws_db_instance.uigraph.master_user_secret[0].secret_arn
}

output "redis_primary_endpoint" {
  description = "ElastiCache primary endpoint. Feed into the chart's redis.host value."
  value       = aws_elasticache_replication_group.uigraph.primary_endpoint_address
}

output "redis_port" {
  value = aws_elasticache_replication_group.uigraph.port
}

output "redis_auth_token_enabled" {
  value = var.redis_auth_token_enabled
}

output "s3_bucket_name" {
  value = aws_s3_bucket.uigraph.id
}

output "s3_bucket_region" {
  value = var.aws_region
}

output "s3_bucket_regional_domain_name" {
  description = "Virtual-hosted S3 URL, a reasonable default for the chart's storage.publicEndpoint value."
  value       = "https://${aws_s3_bucket.uigraph.bucket_regional_domain_name}"
}

output "irsa_role_arn" {
  description = "IAM role ARN to annotate the Helm chart's ServiceAccount with (serviceAccount.annotations.\"eks.amazonaws.com/role-arn\")."
  value       = aws_iam_role.uigraph_irsa.arn
}
