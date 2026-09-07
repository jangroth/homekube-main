terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.37" }
  }
  # Local state — single operator, applied once. Gitignored (see homekube-main/.gitignore).
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_ssoadmin_instances" "this" {}

locals {
  common_tags = {
    Project   = "homekube"
    Stack     = "bootstrap-identity"
    ManagedBy = "terraform"
  }

  # Reused by aws_iam_role_policy.agent_terraform below — keep in sync.
  terraform_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucketLocation",
                    "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
                    "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration",
                    "s3:GetBucketTagging", "s3:PutBucketTagging",
                    "s3:GetBucketPolicy", "s3:ListBucket",
                    # Remaining Get* — provider probes these on every aws_s3_bucket refresh, read-only.
                    "s3:GetBucketAcl", "s3:GetBucketCORS", "s3:GetBucketWebsite",
                    "s3:GetBucketVersioning", "s3:GetAccelerateConfiguration",
                    "s3:GetBucketRequestPayment", "s3:GetBucketLogging",
                    "s3:GetReplicationConfiguration", "s3:GetBucketObjectLockConfiguration",
                    "s3:GetEncryptionConfiguration", "s3:GetBucketOwnershipControls"]
        Resource = ["arn:aws:s3:::homekube-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreateUser", "iam:DeleteUser", "iam:GetUser", "iam:TagUser",
                    "iam:PutUserPolicy", "iam:DeleteUserPolicy", "iam:GetUserPolicy",
                    "iam:CreateAccessKey", "iam:DeleteAccessKey", "iam:ListAccessKeys"]
        Resource = ["arn:aws:iam::*:user/homekube-*"]
      },
      { Effect = "Allow", Action = ["sts:GetCallerIdentity"], Resource = ["*"] }
    ]
  })
}

# --- homekube-terraform: least-privilege, for actual applies ---
resource "aws_ssoadmin_permission_set" "terraform" {
  name             = "homekube-terraform"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT2H"
  tags             = local.common_tags
}

# Scope matches backup-target/main.tf exactly — widen deliberately, never to general admin.
# sts:AssumeRole is added here (not in local.terraform_policy) so agent_terraform's own
# policy doesn't inherit permission to assume itself.
resource "aws_ssoadmin_permission_set_inline_policy" "terraform" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.terraform.arn
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(jsondecode(local.terraform_policy).Statement, [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = [aws_iam_role.agent_terraform.arn]
      }
    ])
  })
}

resource "aws_ssoadmin_account_assignment" "terraform" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.terraform.arn
  principal_id       = var.jan_identity_store_user_id
  principal_type     = "USER"
  target_id          = var.aws_account_id
  target_type        = "AWS_ACCOUNT"
}

# --- homekube-readonly: broad AWS-managed read-only, safe for inspection ---
resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "homekube-readonly"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT2H"
  tags             = local.common_tags
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess doesn't include sts:AssumeRole — grant it separately, scoped to agent_readonly only.
resource "aws_ssoadmin_permission_set_inline_policy" "readonly" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = [aws_iam_role.agent_readonly.arn]
      }
    ]
  })
}

resource "aws_ssoadmin_account_assignment" "readonly" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  principal_id       = var.jan_identity_store_user_id
  principal_type     = "USER"
  target_id          = var.aws_account_id
  target_type        = "AWS_ACCOUNT"
}

# --- Attribution roles ---
# Claude assumes these on top of Jan's active SSO session for CloudTrail attribution only — no standing credential.
# ArnLike wildcard: the SSO-provisioned role name/hash doesn't exist until this apply creates the account assignment.
# VERIFY actual path (`aws iam list-roles --path-prefix /aws-reserved/sso.amazonaws.com/`) and tighten if looser than needed.

resource "aws_iam_role" "agent_terraform" {
  name = "homekube-agent-terraform"
  tags = local.common_tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${var.aws_account_id}:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_homekube-terraform_*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "agent_terraform" {
  name   = "homekube-agent-terraform"
  role   = aws_iam_role.agent_terraform.id
  policy = local.terraform_policy
}

resource "aws_iam_role" "agent_readonly" {
  name = "homekube-agent-readonly"
  tags = local.common_tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${var.aws_account_id}:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_homekube-readonly_*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "agent_readonly" {
  role       = aws_iam_role.agent_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
