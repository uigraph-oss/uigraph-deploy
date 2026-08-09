# Fully automated path: only runs when route53_zone_id is set. Requests + DNS-validates an ACM
# cert covering app./sync./mcp.<domain_name>, then (once the Ingress has an ALB hostname) points
# all three at it with a CNAME. See variables.tf for the alternative — bring your own
# acm_certificate_arn and point DNS yourself, or skip TLS entirely for a first look.
resource "aws_acm_certificate" "this" {
  count                     = var.route53_zone_id != null ? 1 : 0
  domain_name               = "${var.app_subdomain}.${var.domain_name}"
  subject_alternative_names = ["sync.${var.domain_name}", "mcp.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.route53_zone_id != null ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  count                   = var.route53_zone_id != null ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Reads back the ALB hostname the AWS Load Balancer Controller assigns after reconciling the
# Ingress. NOTE: the ALB can take a couple of minutes to provision. If this data source runs
# before it's ready, apply will fail with an empty status — that's expected on a brand-new
# install; just re-run `terraform apply` once the controller's finished (`kubectl get ingress`
# shows an ADDRESS). It's idempotent.
data "kubernetes_ingress_v1" "uigraph" {
  count = var.route53_zone_id != null && var.manage_helm_release ? 1 : 0

  metadata {
    name      = var.helm_release_name
    namespace = var.k8s_namespace
  }

  depends_on = [helm_release.uigraph]
}

resource "aws_route53_record" "app" {
  count   = var.route53_zone_id != null && var.manage_helm_release ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_ingress_v1.uigraph[0].status[0].load_balancer[0].ingress[0].hostname]
}

resource "aws_route53_record" "sync" {
  count   = var.route53_zone_id != null && var.manage_helm_release ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "sync.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_ingress_v1.uigraph[0].status[0].load_balancer[0].ingress[0].hostname]
}

resource "aws_route53_record" "mcp" {
  count   = var.route53_zone_id != null && var.manage_helm_release ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "mcp.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_ingress_v1.uigraph[0].status[0].load_balancer[0].ingress[0].hostname]
}
