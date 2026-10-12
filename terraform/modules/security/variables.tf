variable "vpc_id" {
  description = "ID of the VPC where the security groups will be created"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to access EC2 instances over SSH"
  type        = string
}
