resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  tags   = var.tags

  # Without this, `terraform destroy` fails with BucketNotEmpty the moment the app has ever
  # stored a single asset -- and since versioning is enabled below, even an "empty" bucket (no
  # current objects) can still fail the same way once old versions exist from before an object
  # was overwritten or versioning was suspended. force_destroy purges every version and delete
  # marker, not just current objects, so destroy actually completes unattended. Defaults false
  # since this is real user-uploaded data — opt in per environment (e.g. true for dev, where
  # throwaway teardowns are routine; false for prod, where an accidental destroy shouldn't
  # silently take the asset bucket's contents with it).
  force_destroy = var.s3_force_destroy
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# The browser uploads/downloads directly against S3 using presigned URLs uigraph-api generates
# (PresignPutURL/PresignURL in internal/storage/s3.go) — it never proxies the object bytes
# through the backend. Without this, the browser's CORS preflight on the presigned PUT has
# nothing to authorize it and every upload fails client-side, even though the presigned URL
# itself is valid.
resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  cors_rule {
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = concat(
      ["https://${var.app_subdomain}.${var.domain_name}", "http://${var.app_subdomain}.${var.domain_name}"],
      var.additional_cors_origins,
    )
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Least-privilege: only the app's IRSA role may read/write objects. Everything else, including
# the account root, falls through to the account's default deny.
data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "AllowAppObjectAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.irsa.arn]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid    = "AllowAppBucketList"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.irsa.arn]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}
