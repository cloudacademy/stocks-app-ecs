output "dns" {
  value = aws_alb.alb.dns_name
}

output "id" {
  value = aws_alb.alb.id
}

output "target_groups" {
  value = aws_alb_target_group.alb_target_group
}

output "listener" {
  value = aws_alb_listener.alb_listener
}

output "security_group_id" {
  value = aws_security_group.alb_security_group.id
}
