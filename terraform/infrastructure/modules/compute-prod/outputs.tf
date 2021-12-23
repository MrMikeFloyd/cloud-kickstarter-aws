output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs-cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_deployment_group.cloud-bootstrap-codedeploy-group.app_name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.cloud-bootstrap-codedeploy-group.deployment_group_name
}