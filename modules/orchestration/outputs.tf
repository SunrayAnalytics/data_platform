
output "private_dns_namespace" {
  value = aws_service_discovery_private_dns_namespace.dns_namespace.id
}

output "cluster_id" {
  value = aws_ecs_cluster.sunray_data.id
}

output "service_security_group" {
  value = aws_security_group.ecs_service.id
}

output "dagster_db_secret" {
  value = aws_secretsmanager_secret.dagster_db_credentials.id
}

output "snowflake_db_secret" {
  value = aws_secretsmanager_secret.snowflake_db_credentials.id
}

output "dagster_logs_bucket" {
  value = aws_s3_bucket.dagster_logs.id
}
