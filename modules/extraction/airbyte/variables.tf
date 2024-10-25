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

variable "airbyte_ecr_repository" {
  type        = string
  description = "The url to the ECR repository that contains the reusable airbyte image"
}
variable "private_dns_namespace" {
  type = string
}
variable "cluster_id" {
  type = string
}
variable "service_security_group" {
  type = string
}
variable "dagster_logs_bucket" {
  type = string
}
variable "dagster_db_secret" {
  type = string
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
