locals {
  parameter_prefix = "/data_platform/${var.tenant_id}"
}

resource "aws_ssm_parameter" "repository_base_image" {
  name  = "${local.parameter_prefix}/dbt_project_base_image"
  type  = "String"
  value = aws_ecr_repository.transformation.repository_url
}
resource "aws_ssm_parameter" "cluster_name" {
  name  = "${local.parameter_prefix}/cluster_name"
  type  = "String"
  value = aws_ecs_cluster.sunray_data.name
}
