variable "vpc_id" {
  description = "ID of the VPC containing the target groups"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID assigned to the ALB"
  type        = string
}

variable "blue_instance_id" {
  description = "ID of the Blue EC2 instance"
  type        = string
}

variable "green_instance_id" {
  description = "ID of the Green EC2 instance"
  type        = string
}
