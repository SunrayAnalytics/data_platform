locals {
  dagit_docker_tag = "latest"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_lb_target_group" "dagit_target_group" {
  name        = "dagit-target-group-${var.tenant_id}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc.vpc_id
  target_type = "ip"

  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "aws_lb_listener_rule" "dagster_rule" {

  listener_arn = var.load_balancer_listener_arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dagit_target_group.arn
  }

  condition {
    host_header {
      values = [aws_route53_record.dagster.name]
    }
  }
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

data "aws_route53_zone" "zone" {
  name         = "${var.domain_name}."
  private_zone = false
}

data "aws_lb" "alb" {
  arn = var.load_balancer_arn
}

resource "aws_route53_record" "dagster" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "dagster.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.aws_lb.alb.dns_name]
}

resource "aws_cloudwatch_log_group" "dagit" {
  name              = "/ecs/task/${var.tenant_id}/dagit"
  retention_in_days = 30
}
resource "aws_cloudwatch_log_group" "dagster_deamon" {
  name              = "/ecs/task/${var.tenant_id}/dagster-daemon"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "service" {
  family                   = "dagit-${var.tenant_id}"
  execution_role_arn       = aws_iam_role.dagit_execution_role.arn
  task_role_arn            = aws_iam_role.dagit_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 1024
  cpu                      = 512
  container_definitions = jsonencode([
    {
      name      = "dagit"
      image     = "${aws_ecr_repository.dagit.repository_url}:${local.dagit_docker_tag}"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.dagit.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "dagit"
        }
      },
      secrets = [
        {
          name      = "DAGSTER_PG_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:username::"
        },

        {
          name      = "DAGSTER_PG_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:password::"
        },

        {
          name      = "DAGSTER_PG_HOST"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:host::"
        },
        {
          name      = "DAGSTER_PG_DB"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:database::"
        }
      ],
      environment = [
        {
          name  = "LOG_BUCKET"
          value = aws_s3_bucket.dagster_logs.id
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
          name  = "SUNRAY_TENANT_ID"
          value = var.tenant_id
        }
      ]
    },
    {
      name       = "dagster-daemon"
      image      = "${aws_ecr_repository.dagit.repository_url}:${local.dagit_docker_tag}"
      cpu        = 256
      memory     = 512
      essential  = true
      entryPoint = ["dagster-daemon", "run"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.dagit.name
          awslogs-region        = "eu-west-1" #TODO Current Region here
          awslogs-stream-prefix = "dagster-daemon"
        }
      },
      secrets = [
        {
          name      = "DAGSTER_PG_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:username::"
        },

        {
          name      = "DAGSTER_PG_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:password::"
        },

        {
          name      = "DAGSTER_PG_HOST"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:host::"
        },
        {
          name      = "DAGSTER_PG_DB"
          valueFrom = "${aws_secretsmanager_secret.dagster_db_credentials.id}:database::"
        }
      ],
      environment = [
        {
          name  = "LOG_BUCKET"
          value = aws_s3_bucket.dagster_logs.id
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
          name  = "LB_DNS_NAME"
          value = "main_pipeline_production.data.sunray.local"
        },
        {
          name  = "SUNRAY_TENANT_ID"
          value = var.tenant_id
        }
      ]
    }
  ])

  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "aws_iam_role" "dagit_execution_role" {
  name = "dagit-execution-role-${var.tenant_id}"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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
            aws_secretsmanager_secret_version.dagster.arn,
            aws_secretsmanager_secret.dagster_db_credentials.arn,
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
            "arn:aws:s3:::${aws_s3_bucket.dagster_logs.id}/logs",
            "arn:aws:s3:::${aws_s3_bucket.dagster_logs.id}/logs/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.dagster_logs.id}"
          ]
        }
      ]
    })
  }

  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}


resource "aws_security_group" "dagster_security_group" {
  name   = "dagster_security_group-${var.tenant_id}"
  vpc_id = var.vpc.vpc_id
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}

resource "aws_security_group_rule" "dagster_allow_inbound_from_elb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.dagster_security_group.id
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = var.load_balancer_security_group
}

resource "aws_ecs_service" "dagit_service" {
  name            = "dagit-service-${var.tenant_id}"
  cluster         = aws_ecs_cluster.sunray_data.id
  task_definition = aws_ecs_task_definition.service.id
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.vpc.subnet_ids
    security_groups = [aws_security_group.dagster_security_group.id, aws_security_group.ecs_service.id]
  }
  load_balancer {
    container_name   = "dagit"
    container_port   = 3000
    target_group_arn = aws_lb_target_group.dagit_target_group.arn
  }
  tags = {
    Application = "dagster"
    Tenant      = var.tenant_id
  }
}
