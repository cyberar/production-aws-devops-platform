output "alb_dns_name" {
  description = "DNS name used to access the application through the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "blue_target_group_arn" {
  description = "ARN of the Blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the Green target group"
  value       = aws_lb_target_group.green.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}
