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

variable "environment_name" {
  description = "The environment makes the resources distinguishable from others and is used for naming resources"
  type        = string
}

variable "airbyte_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "The ec2 size of the airbyte instance"
}

variable "db_security_group_id" {
  type = string
}

variable "db_instance_id" {
  type = string
}

