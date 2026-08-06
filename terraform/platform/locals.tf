resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 4
}

locals {
  bucket_name = coalesce(var.bucket_name, "${var.name_prefix}-${try(random_id.bucket_suffix[0].hex, "")}")
  admin_email = coalesce(var.admin_email, "admin@${var.domain_name}")

  # Only one of these two paths actually runs (see dns-tls.tf / variables.tf's mutual-exclusion
  # validation on acm_certificate_arn); the other yields null, which is a legitimate value here —
  # no certificate at all just means the app's ALB serves plain HTTP.
  effective_acm_certificate_arn = var.route53_zone_id != null ? try(aws_acm_certificate_validation.this[0].certificate_arn, null) : var.acm_certificate_arn
}
