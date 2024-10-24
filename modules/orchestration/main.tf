resource "aws_ecs_cluster" "sunray_data" {
  name = "sunray-data-${var.tenant_id}"
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "aws_service_discovery_private_dns_namespace" "dns_namespace" {
  name        = "${var.tenant_id}.data.sunray.local"
  description = "DNS Namepace"
  vpc         = var.vpc.vpc_id

  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "aws_ecr_repository" "dagit" {
  name                 = "dagit-${var.tenant_id}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "terraform_data" "run_dagit_docker_build_push" {
  # When do we need to update this (is it when commit hash changes?)
  triggers_replace = [
  ]

  provisioner "local-exec" {
    command = "modules/orchestration/bin/build_docker.sh && modules/orchestration/bin/push_docker.sh"
    environment = {
      DockerRepository = aws_ecr_repository.dagit.repository_url
    }
  }
  depends_on = [aws_ecr_repository.dagit]
}

resource "aws_s3_bucket" "dagster_logs" {
  bucket        = "sunray-dagster-logs-${var.tenant_id}"
  force_destroy = true
}

#TODO Figure out why the bucket doesn't allow acls?

# resource "aws_s3_bucket_acl" "dagster_logs" {
#   bucket = aws_s3_bucket.dagster_logs.id
#   acl = "private"
# }

resource "aws_ecr_repository" "transformation" {
  name                 = "dbt_project_base_${var.tenant_id}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Application = "dbt_project"
    Tenant      = var.tenant_id
  }
}

resource "terraform_data" "run_dbt_project_docker_build_push" {
  # When do we need to update this (is it when commit hash changes?)
  triggers_replace = [
  ]

  provisioner "local-exec" {
    command = "dockerimages/transformation_base/bin/build_docker.sh && dockerimages/transformation_base/bin/push_docker.sh"
    environment = {
      DockerRepository = aws_ecr_repository.transformation.repository_url
    }
  }
  depends_on = [aws_ecr_repository.transformation]
}

resource "aws_s3_bucket_ownership_controls" "dagster_logs" {
  bucket = aws_s3_bucket.dagster_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_security_group" "ecs_service" {
  name   = "ecs_service-${var.tenant_id}"
  vpc_id = var.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] # TODO Only allow outbound to private subnets
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
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

resource "aws_secretsmanager_secret" "dagster_db_credentials" {
  name_prefix = "dagster-db-${var.tenant_id}-"

  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
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
    username = "dagster_${var.tenant_id}"
    password = data.aws_secretsmanager_random_password.dagster_password.random_password
    database = "dagster_${var.tenant_id}"
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

module "airbyte" {
  for_each   = { for index, val in toset(var.airbyte_instances) : val.classifier => val }
  source     = "../extraction/airbyte"
  tenant_id  = var.tenant_id
  classifier = each.key

  vpc                        = var.vpc
  db_instance_id             = var.db_instance_id
  db_security_group_id       = var.db_security_group_id
  airbyte_instance_type      = each.value.instance_type
  ecs_service_security_group = aws_security_group.ecs_service.id

  load_balancer_arn            = var.load_balancer_arn
  load_balancer_listener_arn   = var.load_balancer_listener_arn
  load_balancer_security_group = var.load_balancer_security_group

  domain_name = var.domain_name
}

module "dbt_project" {
  for_each = { for index, val in toset(var.dbt_projects) : "${val.github.org}-${val.github.repo}" => val }
  source   = "../dbt_project"
  vpc      = var.vpc

  # Shared resources variables
  db_instance_id       = var.db_instance_id
  db_security_group_id = var.db_security_group_id

  # Coming from this stack
  private_dns_namespace  = aws_service_discovery_private_dns_namespace.dns_namespace.id
  cluster_id             = aws_ecs_cluster.sunray_data.id
  service_security_group = aws_security_group.ecs_service.id

  # Input Variables
  domain_name = var.domain_name
  dbt_project = each.value

  tenant_id           = var.tenant_id
  dagster_db_secret   = aws_secretsmanager_secret.dagster_db_credentials.id
  dagster_logs_bucket = aws_s3_bucket.dagster_logs.id
}
