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
      version = "~> 4.66.1"
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
  create_database =  var.airbyte_enabled

  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }
}

module "lake" {
  source           = "./modules/lake"
  environment_name = var.environment_name
  bucket_name_prefix = "sunray"
}

module "glue" {
  source           = "./modules/glue"
  data_lake_consumer_policy = module.lake.data_lake_consumer_policy
  data_lake_producer_policy = module.lake.data_lake_producer_policy
}

module "airbyte" {
  count = var.airbyte_enabled ? 1 : 0
  source           = "./modules/extraction/airbyte"
  environment_name = var.environment_name

  vpc = {
    availability_zone_names = module.vpc.availability_zone_names
    vpc_id                  = module.vpc.vpc_id
    subnet_ids              = module.vpc.private_subnet_ids
  }
  db_instance_id       = module.shared.db_instance_id
  db_security_group_id = module.shared.db_security_group_id
}

resource "aws_security_group_rule" "allow_bastion_db" {
  count = var.airbyte_enabled ? 1 : 0
  security_group_id        = module.shared.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = module.vpc.bastion_security_group_id
}
