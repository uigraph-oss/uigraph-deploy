# IAM role assumable only by the uigraph ServiceAccount in the target namespace (IRSA). Wire the
# resulting role ARN into the Helm chart's serviceAccount.annotations — app.tf does this
# automatically when manage_helm_release = true.
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  name               = "${var.name_prefix}-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "irsa_policy" {
  statement {
    sid       = "ObjectAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid       = "BucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
}

resource "aws_iam_role_policy" "irsa_s3" {
  name   = "${var.name_prefix}-irsa-s3"
  role   = aws_iam_role.irsa.id
  policy = data.aws_iam_policy_document.irsa_policy.json
}
