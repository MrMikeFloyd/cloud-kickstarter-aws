variable "project" {
  description = "Name of the project."
}

variable "stack" {
  description = "Name of the stack."
}

variable "stage" {}

variable "aws_region" {
  description = "The AWS region to create things in."
}

variable "family" {
  description = "Family of the Task Definition"
  default     = "cloud-bootstrap"
}

variable "container_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 8080
}

variable "task_count" {
  description = "Number of ECS tasks to run"
  default     = 3
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "1024"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "2048"
}

variable "fargate-task-service-role" {
  description = "Name of the stack."
}

variable "cw_log_group" {
  description = "CloudWatch Log Group"
}

variable "cw_log_stream" {
  description = "CloudWatch Log Stream"
  default     = "fargate"
}

variable "image_repo_url" {
  description = "ECR Repository URL"
}

variable "vpc_main_id" {}
variable "aws_private_subnet_ids" {}
variable "aws_alb_trgp_blue_id" {}
variable "aws_alb_trgp_blue_name" {}
variable "aws_alb_trgp_green_id" {}
variable "aws_alb_trgp_green_name" {}
variable "aws_alb_security_group_ids" {}
variable "aws_alb_listener_arn" {}
