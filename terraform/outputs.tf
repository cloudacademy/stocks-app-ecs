output "vpc-id" {
  value = module.vpc.vpc_id
}

output "private-subnets" {
  value = module.vpc.private_subnets
}

output "public-subnets" {
  value = module.vpc.public_subnets
}

output "public-alb-target-groups" {
  value = module.public_alb.target_groups
}

output "public-alb-fqdn" {
  value = module.public_alb.dns
}

output "ecs-task-execution-role-arn" {
  value = module.iam.ecs_task_execution_role_arn
}

output "web_app_wait_command" {
  value       = "until curl -Is --max-time 5 http://${module.public_alb.dns}/api/stocks/csv | grep 'HTTP/1.1 200'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready...'"
  description = "Test command - tests readiness of the web app"
}
