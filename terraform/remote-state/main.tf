# ---------------------------------------------------------------------------------------------------------------------
# Terraform Remote State Resources (S3 bucket for state, DynamoDB table for lock)
# Apply first before initializing any project resources
#
# We'll instantiate 2 buckets and 2 tables, one for each tf stack
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">1.0.0"
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

# Common infrastructure (ci/cd)
resource "aws_s3_bucket" "terraform-backend-state-common" {
  bucket = "terraform-backend-state-${var.project}-${var.submodule_common}"
  acl = "private"
  versioning {
    enabled = true
  }
  tags = {
    Name = "${var.project}-${var.submodule_common}-Terraform-Remote-State-S3"
    Project = var.project
  }
}

resource "aws_dynamodb_table" "terraform-backend-lock-common" {
  name = "terraform-backend-lock-${var.project}-${var.submodule_common}"
  hash_key = "LockID"
  read_capacity = 5
  write_capacity = 5
  attribute {
    name = "LockID" # Must match exactly this name, otherwise locking will fail
    type = "S"
  }
  tags = {
    Name = "${var.project}-${var.submodule_common}-Terraform-Remote-State-DynamoDB"
    Project = var.project
  }
}

# Network/compute infrastructure
resource "aws_s3_bucket" "terraform-backend-state-infra" {
  bucket = "terraform-backend-state-${var.project}-${var.submodule_infra}"
  acl = "private"
  versioning {
    enabled = true
  }
  tags = {
    Name = "${var.project}-${var.submodule_common}-Terraform-Remote-State-S3"
    Project = var.project
  }
}

resource "aws_dynamodb_table" "terraform-backend-lock-infra" {
  name = "terraform-backend-lock-${var.project}-${var.submodule_infra}"
  hash_key = "LockID"
  read_capacity = 5
  write_capacity = 5
  attribute {
    name = "LockID" # Must match exactly this name, otherwise locking will fail
    type = "S"
  }
  tags = {
    Name = "${var.project}-${var.submodule_infra}-Terraform-Remote-State-DynamoDB"
    Project = var.project
  }
}