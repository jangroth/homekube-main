variable "aws_region" {
  description = "AWS region for the IAM Identity Center instance and provider"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used to apply this configuration. Jan's admin SSO profile — the one deliberately-scoped exception (spec 008 §5 Step 0b)."
  type        = string
  default     = "jansso-admin"
}

variable "aws_account_id" {
  description = "AWS account ID that owns the Identity Center instance"
  type        = string
  default     = "010316939032"
}

variable "jan_identity_store_user_id" {
  description = "Identity Center UserId for Jan (jansso) — principal for both permission-set account assignments"
  type        = string
  default     = "192e4408-f0c1-708a-6c47-f957a0335368"
}
