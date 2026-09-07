terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.37" } # >= 6.37.0 for bucket_namespace
  }
  # Local state — single operator. Gitignored (see homekube-main/.gitignore).
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project   = "homekube"
    Stack     = "backup-target"
    ManagedBy = "terraform"
  }
}

# Account-regional namespace (AWS, March 2026) — avoids cross-account name collisions.
# Requires AWS provider >= 6.37.0.
resource "aws_s3_bucket" "backups" {
  bucket           = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-an"
  bucket_namespace = "account-regional"
  tags             = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Backstop only — Longhorn (issue #19) and Velero (issue #21) own actual retention.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "safety-net-expiry"
    status = "Enabled"
    filter {}
    expiration { days = 30 }
    # Multipart parts don't show up in listings — clean them up separately.
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_iam_user" "backup" {
  name = "homekube-backup"
  tags = local.common_tags
}

resource "aws_iam_user_policy" "backup" {
  name = "homekube-backup-s3"
  user = aws_iam_user.backup.name
  # Multipart perms: Velero's AWS plugin requires them, Longhorn multipart-uploads large backups.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.backups.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject", "s3:GetObject", "s3:DeleteObject",
          "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
        ]
        Resource = ["${aws_s3_bucket.backups.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}
