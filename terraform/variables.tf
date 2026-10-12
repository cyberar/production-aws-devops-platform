variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the production VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ssh_allowed_cidr" {
  description = "Trusted public IP/CIDR permitted to SSH into EC2"
  type        = string
}

variable "ami_id" {
  description = "AMI ID used for both EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "github_owner" {
  description = "GitHub username or organization for the repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the GitHub Actions IAM role"
  type        = string
  default     = "main"
}