data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
    account   = "${var.dbt_project.snowflake_account_id}.eu-west-1" # TODO Don't hardcode region
    user      = "SYS_DBT"
    password  = data.aws_secretsmanager_random_password.snowflake_password.random_password
    database  = "PRODUCTION"
    role      = "ETL"
    warehouse = "PROD_ETL"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_ecr_repository" "dbt_project_repository" {
  name                 = "${lower(var.dbt_project.github.org)}-${var.dbt_project.github.repo}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_service_discovery_service" "example" {
  name = "main_pipeline_production" # TODO This has to be amended if we're going multitenant

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
}

resource "aws_ecs_service" "transformation_service" {
  name            = "transformation-service" # TODO Make it so that multiple of these can co-exist
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.transformation.id
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.vpc.subnet_ids
    security_groups = [var.service_security_group]
  }
  service_registries {
    registry_arn = aws_service_discovery_service.example.arn
    port         = 4000
  }
}

resource "aws_cloudwatch_log_group" "dagit" {
  name              = "/ecs/task/transformation" # TODO make each deployment unique
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "transformation" {
  family                   = "transformation" # TODO Make each deployment unique
  execution_role_arn       = aws_iam_role.dagit_execution_role.arn
  task_role_arn            = aws_iam_role.dagit_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 1024
  cpu                      = 256
  container_definitions = jsonencode([
    {
      name      = "main-pipeline"
      image     = "${aws_ecr_repository.dbt_project_repository.repository_url}:latest"
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
        },
        {
          name      = "SNOWFLAKE_USER"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:user::"
        },
        {
          name      = "SNOWFLAKE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:password::"
        },
        {
          name      = "SNOWFLAKE_ACCOUNT"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:account::"
        },
        {
          name      = "DBT_SNOWFLAKE_ROLE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:role::"
        },
        {
          name      = "DBT_SNOWFLAKE_DATABASE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:database::"
        },
        {
          name      = "SNOWFLAKE_WAREHOUSE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_db_credentials.id}:warehouse::"
        }
      ],
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
          value = "3"
        },
        {
          name  = "SNOWFLAKE_SCHEMA"
          value = "DEFAULT"
        },
        {
          name  = "CODE_VERSION"
          value = "latest"
        },
        {
          name  = "ENVIRONMENT"
          value = "prod"
        },
        {
          name  = "DOCUMENTATION_BUCKET"
          value = var.dagster_logs_bucket # TODO Create documentation bucket
        },
        {
          name  = "DAGIT_BASE_URL"
          value = "https://dagster.${var.domain_name}"
        },
        {
          name  = "NOTIFICATION_EMAILS"
          value = "info@sunray.ie"
        }

      ]
    }
  ])

}


data "aws_secretsmanager_secret" "dagster_db_secret" {
  name = var.dagster_db_secret
}

resource "aws_iam_role" "dagit_execution_role" {
  name = "transformation-execution-role"

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
            aws_secretsmanager_secret.snowflake_db_credentials.arn,
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

  inline_policy {
    name = "send-email"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ses:SendEmail",
          ]
          Resource = "*"
          Condition = {
            "ForAllValues:StringLike" = {
              "ses:Recipients" : "*@sunray.ie"
            }
          }
        }
      ]
    })
  }


}
