#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

output "vpc_id" {
  value = aws_vpc.main.id
}

output "availability_zone_names" {
  value = [for zone in data.aws_availability_zones.available.names : zone]
}

output "private_subnet_ids" {
  value = [for net in aws_subnet.private : net.id]
}

output "public_subnet_ids" {
  value = [for net in aws_subnet.public : net.id]
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  value = aws_security_group.bastion_security_group.id
}
