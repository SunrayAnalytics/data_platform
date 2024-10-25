# TODO Maybe only create this if there is at least one airbyte instance specified
resource "aws_ecr_repository" "airbyte" {
  name                 = "airbyte_${var.tenant_id}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Application = "airbyte"
    Tenant      = var.tenant_id
  }
}
locals {
  revision = filesha256("modules/extraction/airbyte/dagster_deployment/dagster_deployment/__init__.py")

  #files_hash = sha256(join("" ,[ for file in fileset("modules/extraction/airbyte/dagster_deployment", "**"): filesha256(file)]))
  files_hash = 4
}
resource "terraform_data" "run_airbyte_docker_build_push" {
  # When do we need to update this (is it when commit hash changes?)
  triggers_replace = [
    local.revision,
    local.files_hash
  ]

  provisioner "local-exec" {
    command = "modules/extraction/airbyte/dagster_deployment/bin/build_docker.sh && modules/extraction/airbyte/dagster_deployment/bin/push_docker.sh"
    environment = {
      DockerRepository = aws_ecr_repository.airbyte.repository_url
    }
  }
  depends_on = [aws_ecr_repository.airbyte]
}
