variable "ami_id" {
  description = "AMI ID to use for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_id" {
  description = "ID of the first public subnet"
  type        = string
}

variable "public_subnet_2_id" {
  description = "ID of the second public subnet"
  type        = string
}

variable "web_security_group_id" {
  description = "Security group ID for the web servers"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for EC2 resource names"
  type        = string
  default     = "production"
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile attached to EC2"
  type        = string
}