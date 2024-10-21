resource "aws_ecs_cluster" "sunray_data" {
  name = "sunray-data"
}

resource "aws_service_discovery_private_dns_namespace" "dns_namespace" {
  name        = "data.sunray.local"
  description = "DNS Namepace"
  vpc         = var.vpc.vpc_id
}

resource "aws_ecr_repository" "dagit" {
  name                 = "dagit"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository" "transformation" {
  name                 = "transformation"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_s3_bucket" "dagster_logs" {
  bucket        = "sunray-dagster-logs"
  force_destroy = true
}

#TODO Figure out why the bucket doesn't allow acls?

# resource "aws_s3_bucket_acl" "dagster_logs" {
#   bucket = aws_s3_bucket.dagster_logs.id
#   acl = "private"
# }

resource "aws_s3_bucket_ownership_controls" "dagster_logs" {
  bucket = aws_s3_bucket.dagster_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_security_group" "ecs_service" {
  name   = "ecs_service"
  vpc_id = var.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] # TODO Only allow outbound to private subnets
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "ecs_service_grpc" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ecs_service.id
  from_port                = 4000
  to_port                  = 4000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_service.id
}

resource "aws_security_group_rule" "database_allow_ecs_service" {
  type                     = "ingress"
  security_group_id        = var.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_service.id
}

resource "aws_security_group_rule" "airbyte_allow_ecs_service" {
  type                     = "ingress"
  security_group_id        = var.airbyte_security_group_id
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_service.id
}

resource "aws_secretsmanager_secret" "dagster_db_credentials" {
  name_prefix = "dagster-db"
}

data "aws_secretsmanager_random_password" "dagster_password" {
  password_length     = 30
  exclude_numbers     = false
  exclude_punctuation = true
  include_space       = false
}

data "aws_db_instance" "default" {
  db_instance_identifier = var.db_instance_id
}

resource "aws_secretsmanager_secret_version" "dagster" {
  secret_id = aws_secretsmanager_secret.dagster_db_credentials.id
  secret_string = jsonencode({
    username = "dagster"
    password = data.aws_secretsmanager_random_password.dagster_password.random_password
    database = "dagster"
    host     = data.aws_db_instance.default.address
    port     = data.aws_db_instance.default.port

  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CREATE WAREHOUSE PROD_ETL WAREHOUSE_SIZE='XSMALL';
# CREATE DATABASE PRODUCTION;
#
# CREATE ROLE ETL;
# GRANT OWNERSHIP ON DATABASE PRODUCTION TO ROLE ETL COPY CURRENT GRANTS;
# GRANT USAGE ON WAREHOUSE PROD_ETL TO ROLE ETL;
#
# CREATE USER SYS_DBT
# PASSWORD = 'yTsvYMvmikmr69XbmQ8fhO3vD5dr7i'
# LOGIN_NAME = 'SYS_DBT'
# DEFAULT_WAREHOUSE = 'PROD_ETL'
# DEFAULT_NAMESPACE = 'PRODUCTION.PUBLIC'
# DEFAULT_ROLE='ETL';
#
# GRANT ROLE ETL TO USER SYS_DBT;

resource "aws_secretsmanager_secret" "snowflake_db_credentials" {
  name_prefix = "snowflake-db"
}

data "aws_secretsmanager_random_password" "snowflake_password" {
  password_length     = 30
  exclude_numbers     = false
  exclude_punctuation = true
  include_space       = false
}

resource "aws_secretsmanager_secret_version" "snowflake" {
  secret_id = aws_secretsmanager_secret.snowflake_db_credentials.id
  secret_string = jsonencode({
    account  = "${var.snowflake_account_id}.eu-west-1"
    user     = "SYS_DBT"
    password = data.aws_secretsmanager_random_password.snowflake_password.random_password
    database = "PRODUCTION"
    role     = "ETL"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
