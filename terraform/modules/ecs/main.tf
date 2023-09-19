resource "aws_ecs_cluster" "ecs_cluster" {
  name = lower("${var.app_name}-cluster")
}

resource "aws_cloudwatch_log_group" "ecs_cw_log_group" {
  for_each = toset(var.app_services)
  name     = lower("${each.key}-logs")
}

resource "aws_security_group" "webapp_security_group" {
  name   = "webapp_security_group"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.public_alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "api_security_group" {
  name   = "api_security_group"
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

#Create task definitions for app services
resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each                 = var.service_config
  family                   = "${lower(var.app_name)}-${each.key}"
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_exec_task_role_arn
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

      secrets = each.key == "Stocks-API" ? [
        {
          name      = "DB_USER"
          valueFrom = "${var.secretsmanager_db_creds_arn}:username::" # aws secrets manager
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.secretsmanager_db_creds_arn}:password::" # aws secrets manager
        }
      ] : []

      environment = each.key == "Stocks-API" ? [
        ##### Stocks-API
        {
          name  = "DB_CONNSTR"
          value = "jdbc:mysql://${var.db_endpoint}:3306/cloudacademy"
        }
        ] : [
        ##### Stocks-APP (frontend)
        {
          name  = "REACT_APP_APIHOSTPORT"
          value = var.public_alb_fqdn
        },
        {
          name  = "NGINX_APP_APIHOSTPORT"
          value = join(":", [var.service_config["Stocks-API"].service_discovery.dns, var.service_config["Stocks-API"].service_discovery.port]) # aws cloud map service discovery
        },
        {
          name  = "NGINX_DNS_RESOLVER"
          value = cidrhost(var.cidr, 2) #VPC DNS
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

#Create public services (frontend)
resource "aws_ecs_service" "public_service" {
  for_each = {
    for service, config in var.service_config :
    service => config if config.is_public
  }

  name                   = "${each.value.name}-Service"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type            = "FARGATE"
  desired_count          = each.value.desired_count
  enable_execute_command = true

  network_configuration {
    subnets          = var.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.webapp_security_group.id]
  }

  load_balancer {
    target_group_arn = var.public_alb_target_groups[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }
}

#Create private services (api)
resource "aws_ecs_service" "private_service" {
  for_each = {
    for service, config in var.service_config :
    service => config if !config.is_public
  }

  name                   = "${each.value.name}-Service"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type            = "FARGATE"
  desired_count          = each.value.desired_count
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.api_security_group.id]
  }

  service_registries {
    registry_arn = var.service_registry_arn # aws cloud map service discovery registration
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
