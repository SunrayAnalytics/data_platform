#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "bastion_instance_id" {
  value = module.vpc.bastion_instance_id
}

output "domain_name" {
  value = var.domain_name
}