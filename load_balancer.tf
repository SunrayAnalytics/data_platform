#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

## Create an internal load balancer (as it is)
#resource "aws_lb" "default" {
#  name            = "lb"
#  internal        = false
#  subnets         = module.vpc.public_subnet_ids
#  security_groups = [aws_security_group.lb.id]
#}
#
## This is the load balancer security group, here we have to add rules for all incoming ports
#resource "aws_security_group" "lb" {
#  name   = "alb-security-group"
#  vpc_id = module.vpc.vpc_id
#
#  ingress {
#    protocol    = "tcp"
#    from_port   = 80
#    to_port     = 80
#    cidr_blocks = [var.my_ip]
#  }
#
#  ingress {
#    protocol    = "tcp"
#    from_port   = 443
#    to_port     = 443
#    cidr_blocks = [var.my_ip]
#  }
#
#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#}
#
#resource "aws_security_group_rule" "allow_connections_from_airbyte" {
#  type                     = "ingress"
#  security_group_id        = module.airbyte.airbyte_security_group_id
#  from_port                = 8000
#  to_port                  = 8000
#  protocol                 = "tcp"
#  source_security_group_id = aws_security_group.lb.id
#}
#
## These below here are specific for aibyte
#resource "aws_lb_target_group" "airbyte" {
#  name        = "airbyte-target-group"
#  port        = 8000
#  protocol    = "HTTP"
#  vpc_id      = module.vpc.vpc_id
#  target_type = "instance"
#  health_check {
#    matcher = "200-499"
#    path    = "/api/v1/health"
#  }
#}
#
#resource "aws_lb_listener" "airbyte" {
#  load_balancer_arn = aws_lb.default.id
#  port              = "80"
#  protocol          = "HTTP"
#  default_action {
#    type = "redirect"
#
#    redirect {
#      port        = "443"
#      protocol    = "HTTPS"
#      status_code = "HTTP_301"
#    }
#  }
#}
#
#resource "aws_lb_listener" "secure_listener" {
#  load_balancer_arn = aws_lb.default.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = aws_acm_certificate.cert.arn
#
#  default_action {
#    type = "fixed-response"
#
#    fixed_response {
#      content_type = "text/html"
#      message_body = file("index.html")
#      status_code  = "200"
#    }
#  }
#}
#
#resource "aws_lb_listener_rule" "static" {
#  listener_arn = aws_lb_listener.secure_listener.arn
#  priority     = 100
#
#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.airbyte.arn
#  }
#
#  condition {
#    host_header {
#      values = [aws_route53_record.airbyte.name]
#    }
#  }
#}
#
#resource "aws_autoscaling_attachment" "asg_attachment_bar" {
#  autoscaling_group_name = module.airbyte.airbyte_autoscaling_group_id
#  lb_target_group_arn    = aws_lb_target_group.airbyte.arn
#
#  lifecycle {
#    ignore_changes = [lb_target_group_arn, autoscaling_group_name]
#  }
#}
#
#data "aws_route53_zone" "selected" {
#  name         = "${var.domain_name}."
#  private_zone = false
#}
#
#resource "aws_route53_record" "airbyte" {
#  zone_id = data.aws_route53_zone.selected.zone_id
#  name    = "airbyte.${data.aws_route53_zone.selected.name}"
#  type    = "CNAME"
#  ttl     = "60"
#  records = [aws_lb.default.dns_name]
#}
#
#resource "aws_route53_record" "dataplatform" {
#  zone_id = data.aws_route53_zone.selected.zone_id
#  name    = "dataplatform.${data.aws_route53_zone.selected.name}"
#  type    = "CNAME"
#  ttl     = "60"
#  records = [aws_lb.default.dns_name]
#}
#
#resource "aws_acm_certificate" "cert" {
#  domain_name       = "*.${var.domain_name}" # TODO if automatic setup doesn't work, then try to end with a dot
#  validation_method = "DNS"
#
#  tags = {
#    Environment = "test"
#  }
#
#  lifecycle {
#    create_before_destroy = true
#  }
#}
#
#resource "aws_route53_record" "example" {
#  for_each = {
#    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#      name   = dvo.resource_record_name
#      record = dvo.resource_record_value
#      type   = dvo.resource_record_type
#    }
#  }
#
#  allow_overwrite = true
#  name            = each.value.name
#  records         = [each.value.record]
#  ttl             = 60
#  type            = each.value.type
#  zone_id         = data.aws_route53_zone.selected.zone_id
#}
#
## TODO It seems like the certificate validation is not completed automatically investigate this
#resource "aws_acm_certificate_validation" "example" {
#  certificate_arn         = aws_acm_certificate.cert.arn
#  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
#}