#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

data "aws_vpc" "dwh" {
  id = var.vpc.vpc_id
}


resource "aws_s3_bucket" "assets_bucket" {
  bucket = "${var.environment_name}-code-assets"

  tags = {
    Name        = "${var.environment_name} Assets"
    Environment = "Prod"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main - ${var.environment_name}"
  subnet_ids = var.vpc.subnet_ids

  tags = {
    Name = "${var.environment_name} My DB subnet group"
  }
}

resource "aws_db_instance" "default" {
  count                       = var.create_database ? 1 : 0
  allocated_storage           = 10
  db_name                     = var.environment_name
  engine                      = "postgres"
  engine_version              = "13.7"
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
}

resource "aws_db_parameter_group" "default" {
  name   = "rds-pg"
  family = "postgres13"
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-security_group"
  vpc_id = data.aws_vpc.dwh.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_route53_zone" "selected" {
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_record" "bastion" {
  count                       = var.create_database ? 1 : 0
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "postgres.${data.aws_route53_zone.selected.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.default[0].address]
}
