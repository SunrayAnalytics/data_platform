#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "bastion_instance_id" {
  value = module.vpc.bastion_instance_id
}

output "db_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "domain_name" {
  value = var.domain_name
}

output "dbt_ecr_repos" {
  value = module.orchestration.dbt_repositories
}
