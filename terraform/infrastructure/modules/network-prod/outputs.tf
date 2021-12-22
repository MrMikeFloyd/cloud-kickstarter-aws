output "vpc_main_id" {
  value = aws_vpc.main.id
}

output "vpc_private_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "alb_address" {
  value = aws_alb.alb.dns_name
}

output "alb_target_group_blue_id" {
  value = aws_alb_target_group.trgp-blue.id
}

output "alb_target_group_blue_name" {
  value = aws_alb_target_group.trgp-blue.name
}

output "alb_target_group_green_id" {
  value = aws_alb_target_group.trgp-green.id
}

output "alb_target_group_green_name" {
  value = aws_alb_target_group.trgp-green.name
}

output "alb_security_group_ids" {
  value = aws_security_group.alb-sg.id
}

output "alb_listener_arn" {
  value = aws_alb_listener.alb-listener.arn
}
