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
  snowflake_account_id      = var.snowflake_account_id

  load_balancer_arn            = aws_lb.default.id
  load_balancer_listener_arn   = aws_lb_listener.secure_listener.id
  load_balancer_security_group = aws_security_group.lb.id
  domain_name                  = var.domain_name
}

module "transformation" {
  source = "./modules/transformation"
  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }

  db_instance_id            = module.shared.db_instance_id
  db_security_group_id      = module.shared.db_security_group_id
  airbyte_security_group_id = module.airbyte.airbyte_security_group_id
  snowflake_account_id      = var.snowflake_account_id

  load_balancer_arn               = aws_lb.default.id
  load_balancer_listener_arn      = aws_lb_listener.secure_listener.id
  load_balancer_security_group    = aws_security_group.lb.id
  domain_name                     = var.domain_name
  private_dns_namespace           = module.orchestration.private_dns_namespace
  cluster_id                      = module.orchestration.cluster_id
  service_security_group          = module.orchestration.service_security_group
  implementation_image_repository = var.implementation_image_repository
  dagster_db_secret               = module.orchestration.dagster_db_secret
  snowflake_db_secret             = module.orchestration.snowflake_db_secret
  dagster_logs_bucket             = module.orchestration.dagster_logs_bucket
}

resource "aws_security_group_rule" "allow_bastion_db" {
  security_group_id        = module.shared.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = module.vpc.bastion_security_group_id
}
