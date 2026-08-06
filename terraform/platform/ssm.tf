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
