
variable "stack" {
  description = "Name of the stack."
  default     = "CloudBootstrap-InitialSetup"
}

variable "project" {
  description = "Name of the project."
  default     = "cc-cloud-bootstrap"
}

variable "aws_region" {
  description = "The AWS region to create things in."
}

variable "aws_profile" {
  description = "AWS profile"
}

# Source repo name and branch
variable "source_repo_name" {
  description = "Source repo name"
  type = string
}

variable "source_repo_main_branch_name" {
  description = "Source repo branch"
  type = string
}

# Image repo name for ECR
variable "image_repo_name" {
  description = "Image repo name"
  type = string
}

variable "container_name" {
  description = "Name of the container created with the build pipeline"
}
