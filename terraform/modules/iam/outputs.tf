output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_exec_task_role_arn" {
  value = aws_iam_role.ecs_exec_task_role.arn
}
