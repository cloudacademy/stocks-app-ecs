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
  region = "us-west-2"
}

data "aws_availability_zones" "available" {}

#====================================

locals {
  public_alb_target_groups = { for service, config in var.microservice_config : service => config.alb_target_group if config.is_public }

  rds = {
    master_username = "root"
    master_password = "followthewhiterabbit"
    db_name         = "cloudacademy"
  }
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
}

#====================================

module "cloudmap" {
  source = "./modules/cloudmap"
  vpc_id = module.vpc.vpc_id
}

#====================================

module "secretsmanager" {
  source          = "./modules/secretsmanager"
  master_username = local.rds.master_username
  master_password = local.rds.master_password
  db_name         = local.rds.db_name
}

#====================================

module "aurora" {
  source              = "./modules/aurora"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  ingress_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  master_username     = local.rds.master_username
  master_password     = local.rds.master_password
  db_name             = local.rds.db_name
  secret_manager_arn  = module.secretsmanager.arn
}

#====================================

module "ecs" {
  source                       = "./modules/ecs"
  app_name                     = var.app_name
  app_services                 = var.app_services
  region                       = var.region
  service_config               = var.microservice_config
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn
  ecs_exec_task_role_arn       = module.iam.ecs_exec_task_role_arn
  vpc_id                       = module.vpc.vpc_id
  private_subnets              = module.vpc.private_subnets
  public_subnets               = module.vpc.public_subnets
  public_alb_security_group_id = module.public_alb.security_group_id
  public_alb_target_groups     = module.public_alb.target_groups
  db_endpoint                  = module.aurora.db_endpoint
  public_alb_fqdn              = module.public_alb.dns
  service_registry_arn         = module.cloudmap.service_registry_arn

  depends_on = [
    module.iam,
    module.vpc,
    module.public_alb,
    module.secretsmanager,
    module.aurora,
  ]
}
