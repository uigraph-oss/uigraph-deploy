resource "aws_s3_bucket" "uigraph" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "uigraph" {
  bucket = aws_s3_bucket.uigraph.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uigraph" {
  bucket = aws_s3_bucket.uigraph.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "uigraph" {
  bucket = aws_s3_bucket.uigraph.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Least-privilege: only the IRSA role uigraph-api/uigraph-gateway assume may read/write objects.
# Everything else (including the account root) falls through to the account's default deny.
data "aws_iam_policy_document" "uigraph_bucket" {
  statement {
    sid    = "AllowIRSARoleObjectAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.uigraph_irsa.arn]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.uigraph.arn}/*"]
  }

  statement {
    sid    = "AllowIRSARoleBucketList"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.uigraph_irsa.arn]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.uigraph.arn]
  }
}

resource "aws_s3_bucket_policy" "uigraph" {
  bucket = aws_s3_bucket.uigraph.id
  policy = data.aws_iam_policy_document.uigraph_bucket.json
}
