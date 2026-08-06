resource "kubernetes_namespace" "this" {
  count = var.k8s_namespace == "default" ? 0 : 1
  metadata {
    name = var.k8s_namespace
  }
}

# secret_management = "terraform" only — see rds.tf/variables.tf for the "external-secrets" path,
# where these three values don't exist in Terraform at all and secrets.existingSecret points at a
# Secret you manage outside Terraform instead.
resource "random_password" "uigraph_secret_key" {
  count   = var.secret_management == "terraform" ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "admin_password" {
  count   = var.secret_management == "terraform" && var.admin_password == null ? 1 : 0
  length  = 20
  special = false
}

locals {
  admin_password_value = var.admin_password != null ? var.admin_password : try(random_password.admin_password[0].result, null)

  # Only meaningful when secret_management = "terraform" (see kubernetes_secret.uigraph below) —
  # wrapped in try() throughout since these resources have count = 0 in "external-secrets" mode,
  # same reasoning as azs in cluster/locals.tf: both branches of an expression get evaluated
  # regardless of which one is ultimately used.
  secret_data = {
    uigraph-secret-key  = try(random_password.uigraph_secret_key[0].result, "")
    storage-access-key  = ""
    storage-secret-key  = ""
    postgres-password   = try(random_password.postgres[0].result, "")
    admin-password      = try(local.admin_password_value, "")
    figma-client-secret = var.figma_client_secret
    redis-auth-token    = var.redis_auth_token_enabled ? var.redis_auth_token : ""
    ai-provider-api-key = var.ai_provider_api_key != null ? var.ai_provider_api_key : ""
  }

  base_helm_values = {
    serviceAccount = {
      name = var.k8s_service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.irsa.arn
      }
    }
    secrets = {
      existingSecret = var.secret_management == "terraform" ? kubernetes_secret.uigraph[0].metadata[0].name : var.external_secret_name
    }
    postgres = {
      host     = aws_db_instance.this.address
      port     = aws_db_instance.this.port
      database = var.db_name
      user     = var.db_username
      sslmode  = "require"
    }
    redis = {
      host        = aws_elasticache_replication_group.this.primary_endpoint_address
      port        = aws_elasticache_replication_group.this.port
      tls         = true
      authEnabled = var.redis_auth_token_enabled
    }
    storage = {
      backend        = "s3"
      bucket         = aws_s3_bucket.this.id
      region         = var.aws_region
      publicEndpoint = "https://${aws_s3_bucket.this.bucket_regional_domain_name}"
      forcePathStyle = false
    }
    app = {
      domain     = var.domain_name
      adminEmail = local.admin_email
    }
    ingress = {
      enabled        = true
      className      = "alb"
      certificateArn = local.effective_acm_certificate_arn
      scheme         = var.exposure_mode == "public" ? "internet-facing" : "internal"
    }
    figma = {
      clientId = var.figma_client_id
    }
    gateway = {
      aiProvider = {
        npm        = var.ai_provider_npm
        model      = var.ai_provider_model != null ? var.ai_provider_model : ""
        titleModel = var.ai_provider_title_model != null ? var.ai_provider_title_model : ""
      }
    }
    # The chart's own checksum/config annotation only covers its own configmap.yaml — it has no
    # visibility into this Terraform-managed Secret's contents (secrets.existingSecret), so
    # without this, a secret-only change (e.g. rotating ai_provider_api_key) would update the
    # Secret object but never actually roll the pods that read it.
    podAnnotations = {
      "checksum/secret" = var.secret_management == "terraform" ? sha256(jsonencode(local.secret_data)) : ""
    }
  }
}

# Only rendered when secret_management = "terraform" — the chart references it via
# secrets.existingSecret above rather than rendering its own (see k8s/helm/uigraph/templates/secret.yaml).
resource "kubernetes_secret" "uigraph" {
  count = var.secret_management == "terraform" ? 1 : 0

  metadata {
    name      = "${var.helm_release_name}-secret"
    namespace = var.k8s_namespace
  }

  type = "Opaque"

  # storage-access-key/storage-secret-key are left blank on purpose: the app prefers the pod's
  # IRSA role over these when one is present (see terraform/README.md's "Storage credentials"
  # section), and this Terraform never creates a static IAM user. Both keys still need to exist
  # in the Secret regardless — the chart's Deployments reference them by name via secretKeyRef.
  data = local.secret_data

  depends_on = [kubernetes_namespace.this]
}

resource "helm_release" "uigraph" {
  count = var.manage_helm_release ? 1 : 0

  name      = var.helm_release_name
  chart     = var.helm_chart_path
  namespace = var.k8s_namespace

  # Deep-merged in order, same as `helm install -f base.yaml -f override.yaml` — override wins on
  # conflicting keys, everything else from base survives untouched.
  values = [
    yamlencode(local.base_helm_values),
    yamlencode(var.helm_values_override),
  ]

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_secret.uigraph,
    aws_iam_role_policy.irsa_s3,
    helm_release.alb_controller,
  ]
}
