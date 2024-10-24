data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Generate a fixed length project-id
  project_id = md5("${var.tenant_id}/${var.dbt_project.github.org}/${var.dbt_project.github.repo}")
}

resource "aws_secretsmanager_secret" "snowflake_db_credentials" {
  name = "snowflake-db-${local.project_id}"

  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}

data "aws_secretsmanager_random_password" "snowflake_password" {
  password_length     = 30
  exclude_numbers     = false
  exclude_punctuation = true
  include_space       = false
}

# Send in all these details, or create the user in snowflake
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
  name                 = "dbt_project_${local.project_id}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}

resource "aws_service_discovery_service" "dns_name" {
  name = "dbt_proj-${local.project_id}" # TODO This has to be amended if we're going multitenant

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
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}

resource "aws_ecs_service" "transformation_service" {
  name            = "dagster-grpc-${local.project_id}" # TODO Make it so that multiple of these can co-exist
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.transformation.id
  # We start of with a desired count of 0, the ci/cd pipeline should set this to 1 once the
  # docker repository is populated
  desired_count = 0
  launch_type   = "FARGATE"
  network_configuration {
    subnets         = var.vpc.subnet_ids
    security_groups = [var.service_security_group]
  }
  service_registries {
    registry_arn = aws_service_discovery_service.dns_name.arn
    port         = 4000
  }
  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_cloudwatch_log_group" "dagit" {
  name              = "/ecs/task/${var.tenant_id}/${var.dbt_project.github.org}/${var.dbt_project.github.repo}"
  retention_in_days = 30
  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}

resource "aws_ecs_task_definition" "transformation" {
  family                   = "dagster-grpc-${local.project_id}"
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
          value = "1"
        },
        {
          name  = "SNOWFLAKE_SCHEMA"
          value = "DEFAULT"
        },
        { # TODO Here, we'd like to send in the commit hash
          name  = "CODE_VERSION"
          value = "latest"
        },
        { # TODO Figure out whether we need this?
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
        { # TODO Make the notification e-mail configurable
          name  = "NOTIFICATION_EMAILS"
          value = "info@sunray.ie"
        },
        {
          name  = "SUNRAY_TENANT_ID"
          value = var.tenant_id
        }

      ]
    }
  ])

  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}


data "aws_secretsmanager_secret" "dagster_db_secret" {
  name = var.dagster_db_secret
}

resource "aws_iam_role" "dagit_execution_role" {
  name = "dbt-project-role-${local.project_id}"

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

  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }

}
