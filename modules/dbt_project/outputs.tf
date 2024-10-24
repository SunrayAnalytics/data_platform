output "dbt_project_repository" {
  value = aws_ecr_repository.dbt_project_repository
}

output "github" {
  value = var.dbt_project.github
}

output "dbt_project_configuration" {
  value = {
    AWS_ROLE           = aws_iam_role.github_oidc_role.arn
    AWS_DEFAULT_REGION = "eu-west-1" # TODO Don't hardcode
    TENANT_ID          = var.tenant_id
  }
}


output "dagster_deployment" {
  value = {
    dns_name   = aws_service_discovery_service.dns_name.name
    identifier = "${var.dbt_project.github.org}-${var.dbt_project.github.repo}"
  }
}
