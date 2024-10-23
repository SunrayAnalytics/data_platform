#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

terraform {
  backend "local" {
    path = "state/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.63"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source           = "./modules/vpc"
  environment_name = var.environment_name
  domain_name      = var.domain_name
}

module "shared" {
  source           = "./modules/shared"
  environment_name = var.environment_name
  domain_name      = var.domain_name

  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }
}

module "airbyte" {
  source           = "./modules/extraction/airbyte"
  environment_name = var.environment_name

  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }
  db_instance_id        = module.shared.db_instance_id
  db_security_group_id  = module.shared.db_security_group_id
  airbyte_instance_type = "t3.medium"
}

module "orchestration" {
  source = "./modules/orchestration"

  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }

  db_instance_id            = module.shared.db_instance_id
  db_security_group_id      = module.shared.db_security_group_id
  airbyte_security_group_id = module.airbyte.airbyte_security_group_id

  load_balancer_arn            = aws_lb.default.id
  load_balancer_listener_arn   = aws_lb_listener.secure_listener.id
  load_balancer_security_group = aws_security_group.lb.id

  # Input arguments
  domain_name  = var.domain_name
  dbt_projects = var.dbt_projects
}


resource "aws_security_group_rule" "allow_bastion_db" {
  security_group_id        = module.shared.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = module.vpc.bastion_security_group_id
}
