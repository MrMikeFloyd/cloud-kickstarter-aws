# ---------------------------------------------------------------------------------------------------------------------
# Terraform Remote State Resources (S3 bucket for state, DynamoDB table for lock)
# Apply first before initializing any project resources
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

resource "aws_s3_bucket" "terraform-backend-state" {
  bucket = "tf-backend-state-${var.project}"
  tags = {
    Name = "${var.stack}-Terraform-Remote-State-S3"
    Project = var.project
  }
}

resource "aws_s3_bucket_acl" "terraform-backend-state-acl" {
  bucket = aws_s3_bucket.terraform-backend-state.id
  acl = "private"
}

resource "aws_s3_bucket_versioning" "terraform-backend-state-versioning" {
  bucket = aws_s3_bucket.terraform-backend-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform-backend-lock" {
  name = "tf-backend-lock-${var.project}"
  hash_key = "LockID"
  read_capacity = 5
  write_capacity = 5
  attribute {
    name = "LockID" # Must match exactly this name, otherwise locking will fail
    type = "S"
  }
  tags = {
    Name = "${var.stack}-Terraform-Remote-State-DynamoDb"
    Project = var.project
  }
}