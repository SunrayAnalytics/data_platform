data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amzn-linux-2023-ami.id
  instance_type = var.bastion_instance_type

  # Prevent shells on this machine, we only use it to jump
  user_data = <<-EOF
  #!/bin/bash
  sudo usermod ec2-user -s /sbin/nologin
  EOF

  subnet_id              = aws_subnet.public["eu-west-1a"].id # TODO We have to be able to just choose the first one here possibly convert to ASG?
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  credit_specification {
    cpu_credits = "unlimited"
  }
  tags = {
    Name = "${var.environment_name} - Bastion"
  }
}

resource "aws_security_group" "bastion_security_group" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
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
    Name = "${var.environment_name} Bastion Security Group"
  }
}

data "aws_route53_zone" "selected" {
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "bastion.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.bastion.public_ip]
}