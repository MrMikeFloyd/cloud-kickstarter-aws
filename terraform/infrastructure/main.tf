# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER FOR TF CLOUD
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = "~>0.14"
  backend "s3" {
    # Setting variables in the backend section isn't possible as of now, see https://github.com/hashicorp/terraform/issues/13022
    bucket = "terraform-backend-state-cc-cloud-bootstrap"
    # TODO: Investigate how to set dynamically
    encrypt = true
    dynamodb_table = "terraform-backend-lock-cc-cloud-bootstrap"
    # TODO: Investigate how to set dynamically
    key = "terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

module "cicd" {
  source = "./modules/cicd"
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  image_repo_name = var.image_repo_name
  source_repo_branch = var.source_repo_branch
  source_repo_name = var.source_repo_name
  family = var.family
}

module "compute" {
  source = "./modules/compute"
  depends_on = [module.network.alb_security_group_ids]
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  fargate-task-service-role = var.fargate-task-service-role
  image_repo_url = module.cicd.image_repo_url
  aws_alb_trgp_id = module.network.alb_target_group_id
  aws_private_subnet_ids = module.network.vpc_private_subnet_ids
  alb_security_group_ids = module.network.alb_security_group_ids
  vpc_main_id = module.network.vpc_main_id
}

module "network" {
  source = "./modules/network"
  project = var.project
  stack = var.stack
  az_count = var.az_count
  vpc_cidr = var.vpc_cidr
}

output "source_repo_clone_url_http" {
  value = module.cicd.source_repo_clone_url_http
}

output "alb_address" {
  value = module.network.alb_address
}