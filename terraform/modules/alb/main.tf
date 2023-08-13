resource "aws_security_group" "alb_security_group" {
  name   = "alb_security_group"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.subnets
  security_groups    = [aws_security_group.alb_security_group.id]
}

#Dynamically create the alb target groups for app services
resource "aws_alb_target_group" "alb_target_group" {
  for_each = {
    for service, tg in var.target_groups :
    service => tg if tg != null
  }

  name        = "${lower(each.key)}-tg"
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path     = each.value.health_check_path
    protocol = each.value.protocol
  }

}

#Create the alb listener for the load balancer
resource "aws_alb_listener" "alb_listener" {
  for_each          = var.listeners
  load_balancer_arn = aws_alb.alb.id
  port              = each.value["listener_port"]
  protocol          = each.value["listener_protocol"]

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No routes defined"
      status_code  = "200"
    }
  }
}

#Creat listener rules
resource "aws_alb_listener_rule" "alb_listener_rule" {
  for_each = {
    for service, tg in var.target_groups :
    service => tg if tg != null
  }

  listener_arn = aws_alb_listener.alb_listener[each.value.protocol].arn

  priority = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_target_group[each.key].arn
  }
  condition {
    path_pattern {
      values = each.value.path_pattern
    }
  }
}
