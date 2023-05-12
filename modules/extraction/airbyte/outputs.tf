#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "airbyte_autoscaling_group_id" {
  value = aws_autoscaling_group.airbyte.id
}

output "airbyte_security_group_id" {
  value = aws_security_group.airbyte_security_group.id
}
