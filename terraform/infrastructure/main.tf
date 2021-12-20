# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER FOR TF CLOUD
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">1.0.0"
  backend "s3" {
    # Setting variables in the backend section isn't possible as of now, see https://github.com/hashicorp/terraform/issues/13022
    bucket = "terraform-backend-state-cc-cloud-bootstrap-infrastructure"
    encrypt = true
    dynamodb_table = "terraform-backend-lock-cc-cloud-bootstrap-infrastructure"
    key = "terraform.tfstate"
    region = "eu-central-1"
  }
}

# Inject the common stack's output vars (like ECR repo URL) from its remote state
data "terraform_remote_state" "common-infra" {
  backend = "s3"
  config = {
    bucket = "terraform-backend-state-cc-cloud-bootstrap-common"
    key="terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

module "compute" {
  source = "./modules/compute"
  depends_on = [
    module.network.alb_security_group_ids
  ]
  # Retrieve the common stack's ECR Repo URL from the remote state
  image_repo_url = data.terraform_remote_state.common-infra.outputs.source_repo_image_url
  project = var.project
  stack = var.stack
  environment = var.environment
  aws_region = var.aws_region
  fargate-task-service-role = var.fargate-task-service-role
  aws_alb_trgp_id = module.network.alb_target_group_id
  aws_private_subnet_ids = module.network.vpc_private_subnet_ids
  alb_security_group_ids = module.network.alb_security_group_ids
  vpc_main_id = module.network.vpc_main_id
}

module "network" {
  source = "./modules/network"
  project = var.project
  stack = var.stack
  environment = var.environment
  az_count = var.az_count
  vpc_cidr = var.vpc_cidr
}

output "alb_address" {
  value = module.network.alb_address
}