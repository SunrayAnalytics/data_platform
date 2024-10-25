#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "airbyte_autoscaling_group_id" {
  value = aws_autoscaling_group.airbyte.id
}

output "airbyte_security_group_id" {
  value = aws_security_group.airbyte_security_group.id
}

output "dagster_deployment" {
  value = {
    dns_name   = aws_service_discovery_service.dns_name.name
    identifier = "airbyte-${var.classifier}"
  }
}
