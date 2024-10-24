
locals {
  parameter_prefix = "/data_platform/${var.tenant_id}/dbt_project/${var.dbt_project.github.org}/${var.dbt_project.github.repo}"
}

resource "aws_ssm_parameter" "repository" {
  name  = "${local.parameter_prefix}/ecr_repository_url"
  type  = "String"
  value = aws_ecr_repository.dbt_project_repository.repository_url
}

resource "aws_ssm_parameter" "snowflake_secret" {
  name  = "${local.parameter_prefix}/snowflake_secret"
  type  = "String"
  value = aws_secretsmanager_secret.snowflake_db_credentials.name
}

resource "aws_ssm_parameter" "service_name" {
  name  = "${local.parameter_prefix}/service_name"
  type  = "String"
  value = aws_ecs_service.transformation_service.name
}
