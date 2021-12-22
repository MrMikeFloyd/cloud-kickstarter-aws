# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER FOR TF CLOUD
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">1.0.0"
  backend "s3" {
    # Setting variables in the backend section isn't possible as of now, see https://github.com/hashicorp/terraform/issues/13022
    bucket = "terraform-backend-state-cc-cloud-bootstrap-common"
    encrypt = true
    dynamodb_table = "terraform-backend-lock-cc-cloud-bootstrap-common"
    key = "terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

module "cicd" {
  # Instantiate ci/cd infrastructure once for all environments
  source = "./modules/cicd"
  project = var.project
  stack = var.stack
  aws_region = var.aws_region
  image_repo_name = var.image_repo_name
  source_repo_main_branch_name = var.source_repo_main_branch_name
  source_repo_name = var.source_repo_name
  container_name = var.container_name
}

output "source_repo_image_url" {
  value = module.cicd.image_repo_url
}

output "source_repo_clone_url_http" {
  value = module.cicd.source_repo_clone_url_http
}
