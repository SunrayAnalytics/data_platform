output "project_configuration" {
  value = { for _, proj in module.dbt_project :
  "${proj.github.org}/${proj.github.repo}" => proj.dbt_project_configuration }
}
