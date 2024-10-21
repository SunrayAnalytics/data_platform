#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

variable "aws_region" {
  type        = string
  description = "The region where resources should be provisioned"
}

variable "environment_name" {
  type        = string
  description = "A unique identifier for your environment to help distinguish from other resources in your cloud provider account"
}

variable "domain_name" {
  type        = string
  description = "The name of your domain, this must be set up as a zone in your cloud provider account"
}

variable "my_ip" {
  type    = string
  default = "185.206.192.12/32"
}

variable "snowflake_account_id" {
  type = string
}