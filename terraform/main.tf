module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  vpc_name             = "production-devops-vpc"
  public_subnet_cidr   = "10.0.1.0/24"
  public_subnet_2_cidr = "10.0.2.0/24"
  availability_zone_1  = "us-east-1a"
  availability_zone_2  = "us-east-1b"
}

module "security" {
  source = "./modules/security"

  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "ec2" {
  source = "./modules/ec2"

  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  public_subnet_id          = module.vpc.public_subnet_id
  public_subnet_2_id        = module.vpc.public_subnet_2_id
  web_security_group_id     = module.security.web_security_group_id
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
  name_prefix               = "production"
}

module "alb" {
  source = "./modules/alb"

  vpc_id = module.vpc.vpc_id

  public_subnet_ids = [
    module.vpc.public_subnet_id,
    module.vpc.public_subnet_2_id
  ]

  alb_security_group_id = module.security.alb_security_group_id

  blue_instance_id  = module.ec2.blue_instance_id
  green_instance_id = module.ec2.green_instance_id
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = "production-devops-app"
}

module "iam" {
  source = "./modules/iam"

  github_owner       = var.github_owner
  github_repository  = var.github_repository
  github_branch      = var.github_branch
  ecr_repository_arn = module.ecr.repository_arn
}