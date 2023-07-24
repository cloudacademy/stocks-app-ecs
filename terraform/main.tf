terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

#====================================

locals {
  public_alb_target_groups = { for service, config in var.microservice_config : service => config.alb_target_group if config.is_public }
}

#====================================

module "iam" {
  source   = "./modules/iam"
  app_name = var.app_name
}

#====================================

module "vpc" {
  source             = "./modules/vpc"
  app_name           = var.app_name
  env                = var.env
  cidr               = var.cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
}

#====================================

module "db_security_group" {
  source        = "./modules/security-group"
  name          = "${lower(var.app_name)}-internal-alb-sg"
  description   = "${lower(var.app_name)}-internal-alb-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.db_config.ingress_rules
  egress_rules  = var.db_config.egress_rules
}

#====================================

module "public_alb_security_group" {
  source        = "./modules/security-group"
  name          = "${lower(var.app_name)}-public-alb-sg"
  description   = "${lower(var.app_name)}-public-alb-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.public_alb_config.ingress_rules
  egress_rules  = var.public_alb_config.egress_rules
}

#====================================

module "public_alb" {
  source            = "./modules/alb"
  name              = "${lower(var.app_name)}-public-alb"
  subnets           = module.vpc.public_subnets
  vpc_id            = module.vpc.vpc_id
  target_groups     = local.public_alb_target_groups
  internal          = false
  listener_port     = 80
  listener_protocol = "HTTP"
  listeners         = var.public_alb_config.listeners
  security_groups   = [module.public_alb_security_group.security_group_id]
}

#====================================

module "cloudmap" {
  source = "./modules/cloudmap"
  vpc_id = module.vpc.vpc_id
}

#====================================

module "ecs" {
  source                      = "./modules/ecs"
  app_name                    = var.app_name
  app_services                = var.app_services
  region                      = var.region
  service_config              = var.microservice_config
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  vpc_id                      = module.vpc.vpc_id
  private_subnets             = module.vpc.private_subnets
  public_subnets              = module.vpc.public_subnets
  public_alb_security_group   = module.public_alb_security_group
  db_security_group           = module.db_security_group
  public_alb_target_groups    = module.public_alb.target_groups
  service_registry_arn        = module.cloudmap.service_registry_arn
  public_alb_fqdn             = module.public_alb.alb_dns
}
