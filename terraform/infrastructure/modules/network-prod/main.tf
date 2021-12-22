# ---------------------------------------------------------------------------------------------------------------------
# NETWORK DETAILS
# ---------------------------------------------------------------------------------------------------------------------

data "aws_availability_zones" "available" {}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.stack}-VPC-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
  tags = {
    Name = "${var.stack}-PrivateSubnet-${var.stage}-${count.index + 1}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PUBLIC SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.stack}-PublicSubnet-${var.stage}-${count.index + 1}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# INTERNET GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.stack}-IGW-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ROUTE FOR PUBLIC SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route" "public-route" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# ---------------------------------------------------------------------------------------------------------------------
# INTERNET GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_eip" "eip" {
  count      = var.az_count
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.stack}-eip-${var.stage}-${count.index + 1}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NAT GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_nat_gateway" "nat" {
  count         = var.az_count
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.eip.*.id, count.index)
  tags = {
    Name = "${var.stack}-NatGateway-${var.stage}-${count.index + 1}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE ROUTE TABLE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table" "private-route-table" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id, count.index)
  }
  tags = {
    Name = "${var.stack}-PrivateRouteTable-${var.stage}-${count.index + 1}"
    Project = var.project
  }
}

resource "aws_route_table_association" "route-association" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private-route-table.*.id, count.index)
}

# ---------------------------------------------------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb" "alb" {
  name = "${var.stack}-alb-${var.stage}"
  subnets = aws_subnet.public.*.id
  security_groups = [
    aws_security_group.alb-sg.id]
  tags = {
    Name = "${var.stack}-ALB-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ALB TARGET GROUPS (WE NEED 2 FOR BLUE/GREEN DEPLOYMENT)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "trgp-blue" {
  name = "${var.stack}-tgrp-blue-${var.stage}"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
    port = 8080
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout = 3
    interval = 8
    matcher = "200"
  }
  tags = {
    Project = var.project
    Stage = var.stage
  }
}

resource "aws_alb_target_group" "trgp-green" {
  name = "${var.stack}-tgrp-green-${var.stage}"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
    port = 8080
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout = 3
    interval = 8
    matcher = "200"
  }
  tags = {
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ALB LISTENER - INITIALLY ROUTE TO THE BLUE GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener" "alb-listener" {
  load_balancer_arn = aws_alb.alb.id
  port = "80"
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.trgp-blue.id
    type = "forward"
  }
  tags = {
    Project = var.project
    Stage = var.stage
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP FOR ALB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "alb-sg" {
  name        = "${var.stack}-alb-sg-${var.stage}"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.stack}-alb-sg-${var.stage}"
    Project = var.project
    Stage = var.stage
  }
}
