output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs-cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}