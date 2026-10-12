output "application_url" {
  description = "URL of the application through the ALB"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "blue_instance_id" {
  description = "ID of the Blue EC2 instance"
  value       = module.ec2.blue_instance_id
}

output "green_instance_id" {
  description = "ID of the Green EC2 instance"
  value       = module.ec2.green_instance_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  value       = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions using OIDC"
  value       = module.iam.github_actions_role_arn
}