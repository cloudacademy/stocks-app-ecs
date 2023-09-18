## APP configurations
#====================================

region       = "us-west-2"
app_name     = "ecs-demo"
env          = "dev"
app_services = ["stocksapp", "stocksapi"]

#VPC configurations
#====================================

cidr               = "10.10.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]
public_subnets     = ["10.10.50.0/24", "10.10.51.0/24"]
private_subnets    = ["10.10.0.0/24", "10.10.1.0/24"]

#Public ALB configurations
#====================================

public_alb_config = {
  name = "Public-Alb"
  listeners = {
    "HTTP" = {
      listener_port     = 80
      listener_protocol = "HTTP"
    }
  }
}

#Microservices
#====================================

microservice_config = {
  "Stocks-API" = {
    name           = "stocksapi"
    image          = "cloudacademydevops/stocks-api:v2"
    is_public      = false
    container_port = 8080
    host_port      = 8080
    service_discovery = {
      dns = "api.cloudacademy.terraform.local",
      port = 8080
    }
    cpu            = 256
    memory         = 512
    desired_count  = 1
    auto_scaling = {
      min_capacity = 1
      max_capacity = 2
      cpu = {
        target_value = 75
      }
      memory = {
        target_value = 75
      }
    }
  },
  "Stocks-App" = {
    name           = "stocksapp"
    image          = "cloudacademydevops/stocks-app:v2"
    is_public      = true
    container_port = 8080
    host_port      = 8080
    alb_target_group = {
      port              = 80
      protocol          = "HTTP"
      path_pattern      = ["/*"]
      health_check_path = "/"
      priority          = 2
    }
    cpu            = 256
    memory         = 512
    desired_count  = 1
    auto_scaling = {
      min_capacity = 1
      max_capacity = 2
      cpu = {
        target_value = 75
      }
      memory = {
        target_value = 75
      }
    }
  }
}
