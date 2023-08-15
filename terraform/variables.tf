# APP
#====================================

variable "region" {
  type        = string
  description = "region"
}

variable "app_name" {
  type        = string
  description = "Application name"
}

variable "app_services" {
  type        = list(string)
  description = "service name list"
}

variable "env" {
  type        = string
  description = "Environment"
}

# VPC
#====================================

variable "cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones that the services are running"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets"
}

#ALB
#====================================

variable "public_alb_config" {
  type = object({
    name = string
    listeners = map(object({
      listener_port     = number
      listener_protocol = string
    }))
  })
  description = "Public ALB configuration"
}

# ECS
#====================================

variable "microservice_config" {
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
    environment = optional(list(object({
      name  = string
      value = string
    })))
    alb_target_group = optional(object({
      port              = number
      protocol          = string
      path_pattern      = list(string)
      health_check_path = string
      priority          = number
    }))

    auto_scaling = optional(object({
      max_capacity = number
      min_capacity = number
      cpu = object({
        target_value = number
      })
      memory = object({
        target_value = number
      })
    }))
  }))
  description = "Microservice configuration"
}

