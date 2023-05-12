#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "db_security_group_id" {
  value = aws_security_group.rds_sg.id
}

output "db_instance_id" {
  value = aws_db_instance.default.id
}