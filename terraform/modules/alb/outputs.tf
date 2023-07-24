output "alb_dns" {
  value = aws_alb.alb.dns_name
}

output "alb_id" {
  value = aws_alb.alb.id
}

output "target_groups" {
  value = aws_alb_target_group.alb_target_group
}

output "aws_alb_listener" {
  value = aws_alb_listener.alb_listener
}
