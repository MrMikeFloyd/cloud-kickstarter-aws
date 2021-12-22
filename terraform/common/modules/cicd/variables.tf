variable "project" {
  description = "Name of the project."
}

variable "stack" {
  description = "Name of the stack."
}

variable "aws_region" {
  description = "The AWS region to create things in."
}

variable "container_name" {
  description = "Name of the container"
}

# Source repo name and branch
variable "source_repo_name" {
  description = "Source repo name"
  type = string
}

variable "source_repo_main_branch_name" {
  description = "Source repo main branch name"
  type = string
}

# Image repo name for ECR
variable "image_repo_name" {
  description = "Image repo name"
  type = string
}