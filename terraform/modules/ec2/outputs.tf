output "blue_instance_id" {
  description = "ID of the Blue EC2 instance"
  value       = aws_instance.blue.id
}

output "green_instance_id" {
  description = "ID of the Green EC2 instance"
  value       = aws_instance.green.id
}

output "blue_public_ip" {
  description = "Public IP address of the Blue EC2 instance"
  value       = aws_instance.blue.public_ip
}

output "green_public_ip" {
  description = "Public IP address of the Green EC2 instance"
  value       = aws_instance.green.public_ip
}

output "blue_instance_arn" {
  value = aws_instance.blue.arn
}

output "green_instance_arn" {
  value = aws_instance.green.arn
}