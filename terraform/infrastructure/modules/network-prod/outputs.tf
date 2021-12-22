output "vpc_main_id" {
  value = aws_vpc.main.id
}

output "vpc_private_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "alb_address" {
  value = aws_alb.alb.dns_name
}

output "alb_target_group_id" {
  value = aws_alb_target_group.trgp.id
}

output "alb_security_group_ids" {
  value = aws_security_group.alb-sg.id
}
