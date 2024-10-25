
resource "aws_service_discovery_service" "dns_name" {
  name = "airbyte-${local.project_id}"

  dns_config {
    namespace_id = var.private_dns_namespace

    dns_records {
      ttl  = 10
      type = "A"
    }
    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
  tags = {
    Tenant      = var.tenant_id
    Classifier  = var.classifier
    Application = "airbyte"
  }
}
resource "aws_ecs_service" "airbyte" {
  name            = "airbyte-grpc-${local.project_id}" # TODO Make it so that multiple of these can co-exist
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.transformation.id
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.vpc.subnet_ids
    security_groups = [var.service_security_group]
  }
  service_registries {
    registry_arn = aws_service_discovery_service.dns_name.arn
    port         = 4000
  }
  tags = {
    Tenant      = var.tenant_id
    Classifier  = var.classifier
    Application = "airbyte"
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_cloudwatch_log_group" "dagit" {
  name              = "/ecs/task/${var.tenant_id}/airbyte/${var.classifier}"
  retention_in_days = 30
  tags = {
    Tenant      = var.tenant_id
    Classifier  = var.classifier
    Application = "airbyte"
  }
}

resource "aws_ecs_task_definition" "transformation" {
  family                   = "airbyte-grpc-${local.project_id}"
  execution_role_arn       = aws_iam_role.airbyte_execution_role.arn
  task_role_arn            = aws_iam_role.airbyte_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 1024
  cpu                      = 256
  container_definitions = jsonencode([
    {
      name      = "main-pipeline"
      image     = "${var.airbyte_ecr_repository}:latest"
      cpu       = 256
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 4000
          hostPort      = 4000
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.dagit.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "pipeline-"
        }
      },
      secrets = [
        {
          name      = "DAGSTER_PG_USERNAME"
          valueFrom = "${var.dagster_db_secret}:username::"
        },

        {
          name      = "DAGSTER_PG_PASSWORD"
          valueFrom = "${var.dagster_db_secret}:password::"
        },

        {
          name      = "DAGSTER_PG_HOST"
          valueFrom = "${var.dagster_db_secret}:host::"
        },
        {
          name      = "DAGSTER_PG_DB"
          valueFrom = "${var.dagster_db_secret}:database::"
        }
      ]
      environment = [
        {
          name  = "LOG_BUCKET"
          value = var.dagster_logs_bucket
        },
        {
          name  = "LOG_PREFIX"
          value = "logs"
        },
        {
          name  = "DAGSTER_MAX_CONCURRENT_RUNS"
          value = "1"
        },
        {
          name  = "DAGIT_BASE_URL"
          value = "https://dagster.${var.domain_name}"
        },
        {
          name  = "SUNRAY_TENANT_ID"
          value = var.tenant_id
        },
        {
          name  = "AIRBYTE_HOST"
          value = "10.0.1.191" # TODO This cannot be hardcoded... find solution! Service Map on internal namespace?
        },
        {
          name  = "AIRBYTE_PORT"
          value = "8000" # Don't hardcode?
        },
        { # TODO Don't hardcode this!
          name  = "AIRBYTE_USERNAME"
          value = "admin"
        },
        { # TODO Don't hardcode this!
          name  = "AIRBYTE_PASSWORD"
          value = "secret"
        }
      ]
    }
  ])

  tags = {
    Tenant      = var.tenant_id
    Classifier  = var.classifier
    Application = "airbyte"
  }
}

data "aws_secretsmanager_secret" "dagster_db_secret" {
  name = var.dagster_db_secret
}

resource "aws_iam_role" "airbyte_execution_role" {
  name = "airbyte-role-${local.project_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  # TODO Stick airbyte secrets in a secretsmanager secret
  inline_policy {
    name = "read-secrets"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "kms:Decrypt"
          ]
          Resource = [
            data.aws_secretsmanager_secret.dagster_db_secret.arn,
            "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alias/aws/secretsmanager"
          ]
        }
      ]

    })
  }
  inline_policy {
    name = "bucket-logging"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:aws:s3:::${var.dagster_logs_bucket}/logs",
            "arn:aws:s3:::${var.dagster_logs_bucket}/logs/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::${var.dagster_logs_bucket}"
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "produce-documentation"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:aws:s3:::${var.dagster_logs_bucket}",
            "arn:aws:s3:::${var.dagster_logs_bucket}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::${var.dagster_logs_bucket}"
          ]
        }
      ]
    })
  }

  tags = {
    Tenant      = var.tenant_id
    Classifier  = var.classifier
    Application = "airbyte"
  }

}
