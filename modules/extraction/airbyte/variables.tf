#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

variable "vpc" {
  type = object({
    availability_zone_names = list(string)
    vpc_id                  = string
    subnet_ids              = list(string)
  })
}

variable "airbyte_instance_type" {
  type        = string
  description = "The ec2 size of the airbyte instance"
}

variable "db_security_group_id" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "load_balancer_arn" {
  type = string
}

variable "load_balancer_listener_arn" {
  type = string
}

variable "load_balancer_security_group" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "classifier" {
  type = string
}

variable "ecs_service_security_group" {
  type = string
}
