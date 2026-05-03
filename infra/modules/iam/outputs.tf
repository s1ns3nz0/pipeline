output "ecs_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_instance_profile_name" {
  description = "ECS instance profile name"
  value       = aws_iam_instance_profile.ecs.name
}

output "ecs_instance_role_arn" {
  description = "ECS instance role ARN"
  value       = aws_iam_role.ecs_instance.arn
}
