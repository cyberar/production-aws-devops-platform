variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the first public subnet"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
}

variable "availability_zone_1" {
  description = "Availability zone for the first public subnet"
  type        = string
}

variable "availability_zone_2" {
  description = "Availability zone for the second public subnet"
  type        = string
}
