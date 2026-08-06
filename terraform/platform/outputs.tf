output "postgres_endpoint" {
  value = aws_db_instance.this.address
}

output "postgres_master_user_secret_arn" {
  description = "Only set when secret_management = \"external-secrets\"."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "s3_bucket_name" {
  value = aws_s3_bucket.this.id
}

output "irsa_role_arn" {
  value = aws_iam_role.irsa.arn
}

output "cost_explorer_policy_arn" {
  value = try(aws_iam_policy.cost_explorer[0].arn, null)
}

output "admin_email" {
  value = local.admin_email
}

output "admin_password" {
  description = "Only set when secret_management = \"terraform\" and admin_password wasn't supplied — read with `terraform output -raw admin_password`."
  value       = try(local.admin_password_value, null)
  sensitive   = true
}

output "app_url" {
  value = "https://app.${var.domain_name}"
}

output "sync_url" {
  value = "https://sync.${var.domain_name}"
}

output "mcp_url" {
  value = "https://mcp.${var.domain_name}"
}

output "alb_hostname" {
  description = "The ALB's own DNS name, once the Ingress has been reconciled (kubectl get ingress). Point your own DNS at this if route53_zone_id wasn't set, or use it directly (with a temporary /etc/hosts entry for app.<domain_name>) for a first look."
  value       = try(data.kubernetes_ingress_v1.uigraph[0].status[0].load_balancer[0].ingress[0].hostname, null)
}

output "manual_helm_install_command" {
  description = "Only relevant when manage_helm_release = false."
  value       = <<-EOT
    helm install ${var.helm_release_name} ${var.helm_chart_path} \
      --namespace ${var.k8s_namespace} \
      --set postgres.host=${aws_db_instance.this.address} \
      --set redis.host=${aws_elasticache_replication_group.this.primary_endpoint_address} \
      --set storage.bucket=${aws_s3_bucket.this.id} \
      --set storage.publicEndpoint=https://${aws_s3_bucket.this.bucket_regional_domain_name} \
      --set app.domain=${var.domain_name} \
      --set ingress.scheme=${var.exposure_mode == "public" ? "internet-facing" : "internal"} \
      --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.irsa.arn} \
      --set secrets.existingSecret=<your Secret name>
  EOT
}
