#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "bastion_instance_id" {
  value = module.vpc.bastion_instance_id
}

output "domain_name" {
  value = var.domain_name
}

output "bronze_bucket" {
  value = module.lake.raw_bucket_id
}

output "silver_bucket" {
  value = module.lake.processed_bucket_id
}

output "gold_bucket" {
  value = module.lake.curated_bucket_id
}

output "assets_bucket" {
  value = module.shared.assets_bucket
}

output "glue_service_role" {
  value = module.glue.glue_service_role
}
