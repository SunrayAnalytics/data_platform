output "dbt_repositories" {
  value = [for proj in module.dbt_project : proj.dbt_project_repository]
}
