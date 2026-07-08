# IAM role assumable (via IRSA / EKS Pod Identity's predecessor) only by the uigraph
# ServiceAccount in the target namespace. Wire the resulting role ARN into the Helm chart's
# serviceAccount.annotations."eks.amazonaws.com/role-arn" value.
data "aws_iam_policy_document" "uigraph_irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "uigraph_irsa" {
  name               = "${var.name_prefix}-irsa"
  assume_role_policy = data.aws_iam_policy_document.uigraph_irsa_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "uigraph_irsa_policy" {
  statement {
    sid       = "ObjectAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.uigraph.arn}/*"]
  }

  statement {
    sid       = "BucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.uigraph.arn]
  }
}

resource "aws_iam_role_policy" "uigraph_irsa" {
  name   = "${var.name_prefix}-irsa-s3"
  role   = aws_iam_role.uigraph_irsa.id
  policy = data.aws_iam_policy_document.uigraph_irsa_policy.json
}
