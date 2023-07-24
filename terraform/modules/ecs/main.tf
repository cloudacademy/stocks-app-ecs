resource "aws_ecs_cluster" "ecs_cluster" {
  name = lower("${var.app_name}-cluster")
}

resource "aws_cloudwatch_log_group" "ecs_cw_log_group" {
  for_each = toset(var.app_services)
  name     = lower("${each.key}-logs")
}

#Create task definitions for app services
resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each                 = var.service_config
  family                   = "${lower(var.app_name)}-${each.key}"
  execution_role_arn       = var.ecs_task_execution_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = each.value.memory
  cpu                      = each.value.cpu

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = each.value.image
      cpu       = each.value.cpu
      memory    = each.value.memory
      essential = true

      environment = each.value.environment == null ? [] : [
        for env in each.value.environment : {
          name  = env.name
          value = env.name != "REACT_APP_APIHOSTPORT" ? env.value : var.public_alb_fqdn
        }
      ]

      portMappings = [
        {
          name          = each.value.name
          protocol      = "tcp"
          containerPort = each.value.container_port
          hostPort : each.value.host_port
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${lower(each.value["name"])}-logs"
          awslogs-region        = var.region
          awslogs-stream-prefix = var.app_name
        }
      }
    }
  ])
}

#Create services for app services
resource "aws_ecs_service" "public_service" {
  for_each = {
    for service, config in var.service_config :
    service => config if config.is_public
  }

  name            = "${each.value.name}-Service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type     = "FARGATE"
  desired_count   = each.value.desired_count

  network_configuration {
    subnets          = each.value.is_public == true ? var.public_subnets : var.private_subnets
    assign_public_ip = each.value.is_public == true ? true : false
    security_groups  = [aws_security_group.webapp_security_group.id]
  }

  load_balancer {
    target_group_arn = var.public_alb_target_groups[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }
}

#Create db service
resource "aws_ecs_service" "db_service" {
  for_each = {
    for service, config in var.service_config :
    service => config if !config.is_public
  }

  name            = "${each.value.name}-Service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type     = "FARGATE"
  desired_count   = each.value.desired_count

  network_configuration {
    subnets          = each.value.is_public == true ? var.public_subnets : var.private_subnets
    assign_public_ip = each.value.is_public == true ? true : false
    security_groups  = [aws_security_group.db_service_security_group.id]
  }

  service_registries {
    registry_arn = var.service_registry_arn
  }
}

resource "aws_appautoscaling_target" "public_service_autoscaling" {
  for_each = {
    for service, config in var.service_config :
    service => config if config.is_public
  }

  max_capacity       = each.value.auto_scaling.max_capacity
  min_capacity       = each.value.auto_scaling.min_capacity
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.public_service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  for_each = {
    for service, config in var.service_config :
    service => config if config.is_public
  }

  name               = "${var.app_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_service_autoscaling[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = each.value.auto_scaling.memory.target_value
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each = {
    for service, config in var.service_config :
    service => config if config.is_public
  }

  name               = "${var.app_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_service_autoscaling[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = each.value.auto_scaling.cpu.target_value
  }
}

resource "aws_security_group" "db_service_security_group" {
  name   = "service_security_group"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.webapp_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "webapp_security_group" {
  name   = "webapp_security_group"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.public_alb_security_group.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
