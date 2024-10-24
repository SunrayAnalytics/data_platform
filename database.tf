#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

resource "aws_db_subnet_group" "default" {
  name       = "main - ${var.tenant_id}"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name   = "${var.tenant_id} My DB subnet group"
    Tenant = var.tenant_id
  }
}

resource "aws_db_instance" "default" {
  allocated_storage           = 10
  db_name                     = var.tenant_id
  engine                      = "postgres"
  engine_version              = "16.4"
  instance_class              = var.db_instance_class
  username                    = "root"
  manage_master_user_password = true
  parameter_group_name        = aws_db_parameter_group.default.name
  skip_final_snapshot         = true
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  db_subnet_group_name        = aws_db_subnet_group.default.name
  depends_on = [
    aws_security_group.rds_sg
  ]

  tags = {
    Tenant = var.tenant_id
  }
}

resource "aws_db_parameter_group" "default" {
  name   = "rds-pg-${var.tenant_id}"
  family = "postgres16"

  # Airbyte Temporal database has issues connecting over SSL (seems to be disabled)
  # see https://github.com/airbytehq/airbyte/issues/39636
  # also see https://github.com/airbytehq/airbyte/discussions/30482
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-security_group-${var.tenant_id}"
  vpc_id = module.vpc.vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "postgres.${data.aws_route53_zone.selected.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.default.address]
}
