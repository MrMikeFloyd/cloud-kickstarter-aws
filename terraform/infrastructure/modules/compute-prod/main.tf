# ---------------------------------------------------------------------------------------------------------------------
# ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.stack}-cluster-${var.stage}"
  tags = {
    Name = "${var.stack}-cluster-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS TASK DEFINITION USING FARGATE - IMAGE VERSION WILL BE SUBSTITUTED BY CODEDEPLOY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "task-def" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.tasks-service-role.arn
  tags = {
    Name = "${var.stack}-ECS-Task-Def-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.image_repo_url}",
    "memory": ${var.fargate_memory},
    "name": "${var.family}",
    "networkMode": "awsvpc",
    "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${var.cw_log_group}",
                "awslogs-region": "${var.aws_region}",
                "awslogs-stream-prefix": "${var.cw_log_stream}"
            }
        },
    "environment": [],
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort": ${var.container_port}
      }
    ]
  }
]
DEFINITION
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP FOR ECS TASKS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "task-sg" {
  name        = "${var.stack}-task-sg-${var.stage}"
  description = "Allow inbound access to ECS tasks from the ALB only"
  vpc_id      = var.vpc_main_id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [var.aws_alb_security_group_ids]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.stack}-task-sg-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS SERVICE - SET DEPLOY CONTROLLER TO CODE_DEPLOY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_service" "service" {
  name            = "${var.stack}-service-${var.stage}"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.task-def.arn
  desired_count   = var.task_count
  launch_type     = "FARGATE"
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  tags = {
    Name = "${var.stack}-ECS-service-${var.stage}"
    Project = var.project
    Stage = var.stage
  }

  network_configuration {
    security_groups = [aws_security_group.task-sg.id]
    subnets         = var.aws_private_subnet_ids
  }

  load_balancer {
    target_group_arn = var.aws_alb_trgp_blue_id
    container_name   = var.family
    container_port   = var.container_port
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEDEPLOY RESOURCES
# Setup according to
# https://catalog.us-east-1.prod.workshops.aws/v2/workshops/869f7eee-d3a2-490b-bf9a-ac90a8fb2d36/en-US/4-basic/lab2-bluegreen/12-codedeployapp
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_codedeploy_app" "cloud-bootstrap-codedeploy-app" {
  compute_platform = "ECS"
  name             = "${var.project}-${var.stage}-app"
  tags = {
    Project = var.project
    Stage = var.stage
  }
}

resource "aws_iam_role" "deploy-to-ecs-role" {
  name = "${var.fargate-task-service-role}-CodeDeployToECS-${var.stage}"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.codedeploy-assume-policy.json
  tags = {
    Project = var.project
    Purpose = "deploy-to-ecs-role"
    Stage = var.stage
  }
}

data "aws_iam_policy_document" "codedeploy-assume-policy" {
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy-role-attachment" {
  role = aws_iam_role.deploy-to-ecs-role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
resource "aws_codedeploy_deployment_group" "cloud-bootstrap-codedeploy-group" {
  app_name = aws_codedeploy_app.cloud-bootstrap-codedeploy-app.name
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"
  deployment_group_name = "${var.project}-${var.stage}-deployment-group"
  service_role_arn = aws_iam_role.deploy-to-ecs-role.arn

  auto_rollback_configuration {
    enabled = true
    events = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs-cluster.name
    service_name = aws_ecs_service.service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.aws_alb_listener_arn]
      }

      target_group {
        name = var.aws_alb_trgp_blue_name
      }

      target_group {
        name = var.aws_alb_trgp_green_name
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloud-bootstrap-cw-lgrp" {
  name = var.cw_log_group
  tags = {
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS TASK ROLE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "tasks-service-role" {
  name = "${var.fargate-task-service-role}-ECSTasksServiceRole-${var.stage}"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.tasks-service-assume-policy.json
  tags = {
    Project = var.project
    Purpose = "tasks-service-role"
    Stage = var.stage
  }
}

data "aws_iam_policy_document" "tasks-service-assume-policy" {
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "tasks-service-role-attachment" {
  role = aws_iam_role.tasks-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}