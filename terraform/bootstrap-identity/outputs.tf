output "terraform_permission_set_arn" {
  value = aws_ssoadmin_permission_set.terraform.arn
}

output "readonly_permission_set_arn" {
  value = aws_ssoadmin_permission_set.readonly.arn
}

output "agent_terraform_role_arn" {
  value = aws_iam_role.agent_terraform.arn
}

output "agent_readonly_role_arn" {
  value = aws_iam_role.agent_readonly.arn
}
