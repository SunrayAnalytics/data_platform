#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#
locals {
  project_id = "${var.tenant_id}-${var.classifier}"
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_db_instance" "default" {
  db_instance_identifier = var.db_instance_id
}

resource "aws_secretsmanager_secret" "airbyte_db_credentials" {
  name_prefix = "airbyte-db-${local.project_id}"

  tags = {
    Tenant     = var.tenant_id
    Classifier = var.classifier
  }
}

data "aws_secretsmanager_random_password" "airbyte_password" {
  password_length     = 30
  exclude_numbers     = false
  exclude_punctuation = true
  include_space       = false
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id = aws_secretsmanager_secret.airbyte_db_credentials.id
  secret_string = jsonencode({
    username = "airbyte_${var.classifier}"
    password = data.aws_secretsmanager_random_password.airbyte_password.random_password
    database = "airbyte_${var.classifier}"
    host     = data.aws_db_instance.default.address
    port     = data.aws_db_instance.default.port

  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}


data "template_file" "setup_sh" {
  template = file("${path.module}/instance_config/setup.sh")
  vars = {
    database_host              = data.aws_db_instance.default.address
    database_port              = data.aws_db_instance.default.port
    database_name              = "airbyte_${var.classifier}"
    database_username          = "airbyte_${var.classifier}"
    master_username            = data.aws_db_instance.default.master_username
    db_master_credentials_arn  = data.aws_db_instance.default.master_user_secret[0].secret_arn
    db_airbyte_credentials_arn = aws_secretsmanager_secret.airbyte_db_credentials.arn
    AWS_REGION                 = data.aws_region.current.name
  }
}

data "template_file" "env_file" {
  template = file("${path.module}/instance_config/env")
  vars = {
  }
}
data "template_file" "bashrc" {
  template = file("${path.module}/instance_config/bashrc")
  vars = {
    AWS_REGION         = data.aws_region.current.name
    AWSLOGS_GROUP      = aws_cloudwatch_log_group.airbyte.name
    DB_CREDENTIALS_ARN = aws_secretsmanager_secret.airbyte_db_credentials.arn
  }
}

data "template_cloudinit_config" "foobar" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"

    content = file("${path.module}/instance_config/cloud-config.yaml")
  }

  part {
    content_type = "text/cloud-config"

    # JSON is a subset of YAML, so cloud-init should
    # still accept this even though it's jsonencode.
    content = jsonencode({
      write_files = [
        {
          content     = data.template_file.setup_sh.rendered
          path        = "/home/ec2-user/setup.sh"
          permissions = "0755"
          #          owner       = "ec2-user"
        },
        {
          content     = data.template_file.env_file.rendered
          path        = "/home/ec2-user/.env"
          permissions = "0644"
          #          owner       = "ec2-user:ec2-user"
        },
        {
          content     = data.template_file.bashrc.rendered
          path        = "/home/ec2-user/.bashrc"
          permissions = "0644"
          #          owner       = "ec2-user:ec2-user"
        },
        {
          content     = file("${path.module}/instance_config/flags.yml")
          path        = "/home/ec2-user/flags.yml"
          permissions = "0644"
          #          owner       = "ec2-user:ec2-user"
        },
        {
          content     = file("${path.module}/instance_config/bash_profile")
          path        = "/home/ec2-user/.bash_profile"
          permissions = "0644"
          #          owner       = "ec2-user:ec2-user"
        },
        {
          content     = file("${path.module}/instance_config/docker-compose.yaml")
          path        = "/home/ec2-user/docker-compose.yaml"
          permissions = "0644"
          #          owner       = "ec2-user:ec2-user"
        }
      ]
    })
  }

}


resource "aws_cloudwatch_log_group" "airbyte" {
  name              = "/ec2/${var.tenant_id}/${var.classifier}/airbyte/docker"
  retention_in_days = 30
  tags = {
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}

data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_autoscaling_group" "airbyte" {

  vpc_zone_identifier = var.vpc.subnet_ids
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1

  launch_template {
    id      = aws_launch_template.airbyte.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.tenant_id} - ${var.classifier} - Airbyte"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = "Airbyte"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tenant"
    value               = var.tenant_id
    propagate_at_launch = true
  }

  tag {
    key                 = "Classifier"
    value               = var.classifier
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [target_group_arns]
  }

}

resource "aws_launch_template" "airbyte" {
  image_id      = data.aws_ami.amzn-linux-2023-ami.id
  instance_type = var.airbyte_instance_type
  iam_instance_profile {
    arn = aws_iam_instance_profile.airbyte_profile.arn
  }

  user_data = data.template_cloudinit_config.foobar.rendered

  #  subnet_id              = var.vpc.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.airbyte_security_group.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type           = "gp2"
      volume_size           = "40"
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name        = "${var.tenant_id} - ${var.classifier} - Airbyte"
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}


resource "aws_iam_instance_profile" "airbyte_profile" {
  name = "airbyte_profile_${local.project_id}"
  role = aws_iam_role.airbyte_role.name

  tags = {
    Name        = "${var.tenant_id} - ${var.classifier} - Airbyte"
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "airbyte_role" {
  name               = "airbyte_role_${local.project_id}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "inline-policy"
    policy = jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "s1",
            "Effect" : "Allow",
            "Action" : "secretsmanager:GetSecretValue",
            "Resource" : [
              data.aws_db_instance.default.master_user_secret[0].secret_arn,
              aws_secretsmanager_secret.airbyte_db_credentials.arn,
              "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/secretsmanager"
            ]
          },
          {
            "Sid" : "s2",
            "Effect" : "Allow",
            "Action" : ["logs:CreateLogStream", "logs:CreateLogStream", "logs:PutLogEvents"],
            "Resource" : [
              aws_cloudwatch_log_group.airbyte.arn,
              "${aws_cloudwatch_log_group.airbyte.arn}:*"
            ]
          }
        ]
      }
    )
  }

  tags = {
    Name        = "${var.tenant_id} - ${var.classifier} - Airbyte"
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}

resource "aws_security_group" "airbyte_security_group" {
  name        = "allow_ssh_http"
  description = "Allow SSH and http inbound traffic"
  vpc_id      = var.vpc.vpc_id


  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 8000
    to_port          = 8000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] # TODO Only allow outbound to private subnets
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.tenant_id} - ${var.classifier} - Airbyte Security Group"
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}

resource "aws_security_group_rule" "db_allow_connections_from_airbyte" {
  type                     = "ingress"
  security_group_id        = var.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airbyte_security_group.id
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = var.load_balancer_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airbyte.arn
  }

  condition {
    host_header {
      values = [aws_route53_record.airbyte.name]
    }
  }
}

data "aws_lb" "alb" {
  arn = var.load_balancer_arn
}

data "aws_route53_zone" "selected" {
  name         = "${var.domain_name}."
  private_zone = false
}
resource "aws_route53_record" "airbyte" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "airbyte.${data.aws_route53_zone.selected.name}"
  type    = "CNAME"
  ttl     = "60"
  records = [data.aws_lb.alb.dns_name]
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.airbyte.id
  lb_target_group_arn    = aws_lb_target_group.airbyte.arn

  lifecycle {
    ignore_changes = [lb_target_group_arn, autoscaling_group_name]
  }
}
resource "aws_security_group_rule" "allow_connections_from_airbyte" {
  type                     = "ingress"
  security_group_id        = aws_security_group.airbyte_security_group.id
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = var.load_balancer_security_group
}

resource "aws_security_group_rule" "airbyte_allow_ecs_service" {
  type                     = "ingress"
  security_group_id        = aws_security_group.airbyte_security_group.id
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = var.ecs_service_security_group
}

# These below here are specific for aibyte
resource "aws_lb_target_group" "airbyte" {
  name        = "ab-tg-${local.project_id}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc.vpc_id
  target_type = "instance"
  health_check {
    matcher = "200-499"
    path    = "/api/v1/health"
  }

  tags = {
    Name        = "${var.tenant_id} - ${var.classifier} - Airbyte"
    Application = "airbyte"
    Tenant      = var.tenant_id
    Classifier  = var.classifier
  }
}
