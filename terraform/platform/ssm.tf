# Durable, encrypted, auditable store for the AI provider API key — the actual value consumed by
# the gateway pod still has to go through the Kubernetes Secret (see app.tf), since
# uigraph-gateway reads it from an env var and has no direct SSM integration. This is that
# env var's source of truth for rotation: update the value here (console, CLI, or this
# variable + re-apply) rather than editing the Secret directly.
resource "aws_ssm_parameter" "ai_provider_api_key" {
  count = var.ai_provider_api_key != null ? 1 : 0

  name        = "/${var.name_prefix}/ai-provider-api-key"
  description = "API key for uigraph-gateway's AI chat feature (AI_PROVIDER_API_KEY)."
  type        = "SecureString"
  value       = var.ai_provider_api_key

  tags = var.tags
}

# Shared secret between this deployment's uigraph-api and the separate, privately-deployed
# uigraph-enterprise service (signup/billing for the managed SaaS product — not part of this
# repo). Only relevant when enterprise_enabled = true; self-hosted deployments never set it.
resource "aws_ssm_parameter" "enterprise_internal_token" {
  count = var.enterprise_internal_token != null ? 1 : 0

  name        = "/${var.name_prefix}/enterprise-internal-token"
  description = "Shared secret authenticating uigraph-enterprise's calls to uigraph-api's internal endpoints (UIGRAPH_ENTERPRISE_INTERNAL_TOKEN)."
  type        = "SecureString"
  value       = var.enterprise_internal_token

  tags = var.tags
}
