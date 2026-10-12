output "ec2_instance_profile_name" {
  description = "Instance profile to attach to both EC2 instances"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_role_arn" {
  description = "IAM role assumed by EC2"
  value       = aws_iam_role.ec2.arn
}

output "github_actions_role_arn" {
  description = "Role ARN used by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions"
  value       = aws_iam_role.github_actions.name
}
