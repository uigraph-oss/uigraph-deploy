output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "Feed into platform/terraform.tfvars as oidc_provider_arn."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "Feed into platform/terraform.tfvars as oidc_provider_url (issuer URL, no leading https://)."
  value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

output "vpc_id" {
  value = local.vpc_id
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "node_security_group_id" {
  description = "Security group shared by EKS worker nodes/pods — feed into platform/terraform.tfvars as node_security_group_id."
  value       = module.eks.node_security_group_id
}

output "configure_kubectl" {
  description = "Command to point your local kubeconfig at this cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}${var.aws_profile != null ? " --profile ${var.aws_profile}" : ""}"
}
