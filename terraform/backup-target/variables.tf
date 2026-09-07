variable "aws_region" {
  description = "AWS region for the bucket and provider"
  type        = string
  default     = "ap-southeast-2"
}

variable "bucket_name" {
  description = "Bucket name prefix — account-regional namespace suffix makes this collision-free"
  type        = string
  default     = "homekube-backups"
}

variable "aws_profile" {
  description = "SSO profile from bootstrap-identity's homekube-terraform permission set"
  type        = string
  default     = "homekube-terraform"
}
