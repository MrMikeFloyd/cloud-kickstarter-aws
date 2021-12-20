variable "aws_region" {
  description = "The AWS region to create things in."
}

variable "project" {
  description = "Name of the project."
  default     = "cc-cloud-bootstrap"
}

variable "aws_profile" {
  description = "AWS profile"
}

variable "submodule_common" {
  description = "Name of submodule for common components."
  default     = "common"
}

variable "submodule_infra" {
  description = "Name of submodule for infrastructure components."
  default     = "infrastructure"
}