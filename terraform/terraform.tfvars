## APP configurations
#====================================

region       = "us-east-1"
app_name     = "ecs-demo"
env          = "dev"
app_services = ["stocksapp", "stocksapi", "stocksdb"]

#VPC configurations
#====================================

cidr               = "10.10.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnets     = ["10.10.50.0/24", "10.10.51.0/24"]
private_subnets    = ["10.10.0.0/24", "10.10.1.0/24"]

#DB configurations
db_config = {
  name = "DB"
  ingress_rules = [
    {
      from_port   = 80
      to_port     = 4000
      protocol    = "tcp"
      cidr_blocks = ["10.10.0.0/16"]
    },
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["10.10.0.0/16"]
    }
  ]
}

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

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

#Microservices
#====================================

microservice_config = {
  "Stocks-DB" = {
    name           = "stocksdb"
    image          = "cloudacademydevops/stocks-db:v1"
    is_public      = false
    container_port = 3306
    host_port      = 3306
    cpu            = 256
    memory         = 512
    desired_count  = 1
    environment = [
      {
      name = "MYSQL_ROOT_PASSWORD"
      value = "fo11owth3wh1t3r4bb1t"
      }
    ]
    alb_target_group = null
    auto_scaling = null
  },
  "Stocks-API" = {
    name           = "stocksapi"
    image          = "cloudacademydevops/stocks-api:v2"
    is_public      = true
    container_port = 8080
    host_port      = 8080
    cpu            = 256
    memory         = 512
    desired_count  = 2
    environment = [
      {
      name = "DB_CONNSTR"
      value = "jdbc:mysql://db.cloudacademy.terraform.local:3306/stocks"
      },
      {
      name = "DB_USER"
      value = "root"
      },
      {
      name = "DB_PASSWORD"
      value = "fo11owth3wh1t3r4bb1t"
      }
    ]
    alb_target_group = {
      port              = 8080
      protocol          = "HTTP"
      path_pattern      = ["/api*"]
      health_check_path = "/api/stocks/ok"
      priority          = 1
    }
    auto_scaling = {
      max_capacity = 4
      min_capacity = 2
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
    image          = "cloudacademydevops/stocks-app:v1"
    is_public      = true
    container_port = 8080
    host_port      = 8080
    cpu            = 256
    memory         = 512
    desired_count  = 2
    environment = [
      {
      name = "REACT_APP_APIHOSTPORT"
      value = "" # dynamically injected at provisioning time by terraform
      }
    ]
    alb_target_group = {
      port              = 80
      protocol          = "HTTP"
      path_pattern      = ["/*"]
      health_check_path = "/"
      priority          = 2
    }
    auto_scaling = {
      max_capacity = 4
      min_capacity = 2
      cpu = {
        target_value = 75
      }
      memory = {
        target_value = 75
      }
    }
  }
}
