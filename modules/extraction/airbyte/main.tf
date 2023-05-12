#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_db_instance" "default" {
  db_instance_identifier = var.db_instance_id
}

resource "aws_secretsmanager_secret" "airbyte_db_credentials" {
  name_prefix = "airbyte-db"
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
    username = "airbyte"
    password = data.aws_secretsmanager_random_password.airbyte_password.random_password
    database = "airbyte"
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
  name              = "/ec2/${var.environment_name}/airbyte/docker"
  retention_in_days = 30
  tags = {
    Environment = var.environment_name
    Application = "airbyte"
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
    value               = "${var.environment_name} - Airbyte"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = "Airbyte"
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
    Name = "${var.environment_name} - Airbyte"
  }
}


resource "aws_iam_instance_profile" "airbyte_profile" {
  name = "airbyte_profile"
  role = aws_iam_role.airbyte_role.name
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
  name               = "airbyte_role"
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
    Name = "${var.environment_name} Airbyte Security Group"
  }
}

resource "aws_security_group_rule" "allow_connections_from_airbyte" {
  type                     = "ingress"
  security_group_id        = var.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airbyte_security_group.id
}

