variable "app_name" {
  type = string
}

variable "app_services" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "service_config" {
  type = map(object({
    name           = string
    image          = string
    is_public      = bool
    container_port = number
    host_port      = number
    cpu            = number
    memory         = number
    desired_count  = number
    service_discovery = optional(object({
      dns  = string
      port = number
    }))
    environment = list(object({
      name  = string
      value = string
    }))

    alb_target_group = object({
      port              = number
      protocol          = string
      path_pattern      = list(string)
      health_check_path = string
      priority          = number
    })

    auto_scaling = object({
      max_capacity = number
      min_capacity = number
      cpu = object({
        target_value = number
      })
      memory = object({
        target_value = number
      })
    })
  }))
}

variable "public_alb_security_group_id" {
  type = string
}

variable "public_alb_target_groups" {
  type = map(object({
    arn = string
  }))
}

variable "db_endpoint" {
  type = string
}

variable "public_alb_fqdn" {
  type = string
}

variable "service_registry_arn" {
  type = string
}
