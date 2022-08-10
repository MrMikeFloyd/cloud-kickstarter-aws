# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER FOR TF CLOUD
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    # Setting variables in the backend section isn't possible as of now, see https://github.com/hashicorp/terraform/issues/13022
    bucket = "tf-backend-state-cc-cloud-bootstrap"
    encrypt = true
    dynamodb_table = "tf-backend-lock-cc-cloud-bootstrap"
    key = "terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

# Shared CI/CD infrastructure
module "cicd" {
  source = "./modules/cicd"
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  image_repo_name = var.image_repo_name
  source_repo_branch = var.source_repo_branch
  source_repo_name = var.source_repo_name
  family = var.family
  ecs_cluster_name_dev = module.compute-dev.ecs_cluster_name
  ecs_service_name_dev = module.compute-dev.ecs_service_name
  codedeploy_application_name = module.compute-prod.codedeploy_app_name
  codedeploy_deployment_group_name = module.compute-prod.codedeploy_deployment_group_name
}

# DEV stage
module "network-dev" {
  source = "./modules/network-dev"
  stage = "dev"
  project = var.project
  stack = var.stack
  az_count = var.az_count_dev
  vpc_cidr = var.vpc_cidr_dev
}
module "compute-dev" {
  source = "./modules/compute-dev"
  stage = "dev"
  depends_on = [module.network-dev.alb_security_group_ids]
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  image_repo_url = module.cicd.image_repo_url
  fargate-task-service-role = var.fargate-task-service-role-dev
  aws_alb_trgp_id = module.network-dev.alb_target_group_id
  aws_private_subnet_ids = module.network-dev.vpc_private_subnet_ids
  alb_security_group_ids = module.network-dev.alb_security_group_ids
  vpc_main_id = module.network-dev.vpc_main_id
  cw_log_group = "${var.project}-dev"
}

# PROD stage
module "network-prod" {
  source = "./modules/network-prod"
  stage = "prod"
  project = var.project
  stack = var.stack
  az_count = var.az_count_prod
  vpc_cidr = var.vpc_cidr_prod
}
module "compute-prod" {
  source = "./modules/compute-prod"
  stage = "prod"
  depends_on = [module.network-prod.alb_security_group_ids]
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  image_repo_url = module.cicd.image_repo_url
  vpc_main_id = module.network-prod.vpc_main_id
  cw_log_group = "${var.project}-prod"
  fargate-task-service-role = var.fargate-task-service-role-prod
  aws_alb_listener_arn = module.network-prod.alb_listener_arn
  aws_alb_security_group_ids = module.network-prod.alb_security_group_ids
  aws_alb_trgp_blue_id = module.network-prod.alb_target_group_blue_id
  aws_alb_trgp_blue_name = module.network-prod.alb_target_group_blue_name
  aws_alb_trgp_green_id = module.network-prod.alb_target_group_green_id
  aws_alb_trgp_green_name = module.network-prod.alb_target_group_green_name
  aws_private_subnet_ids = module.network-prod.vpc_private_subnet_ids
}

output "source_repo_clone_url_http" {
  value = module.cicd.source_repo_clone_url_http
}

output "ecs_task_execution_role_arn_dev" {
  value = module.compute-dev.ecs_task_execution_role_arn
}

output "ecs_task_execution_role_arn_prod" {
  value = module.compute-prod.ecs_task_execution_role_arn
}

output "alb_address_dev" {
  value = module.network-dev.alb_address
}

output "alb_address_prod" {
  value = module.network-prod.alb_address
}
