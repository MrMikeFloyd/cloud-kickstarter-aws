output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs-cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

output "ecs_task_execution_role_arn" {
  value = aws_ecs_task_definition.task-def.execution_role_arn
}