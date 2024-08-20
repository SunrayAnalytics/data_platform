#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

variable "environment_name" {
  description = "The environment makes the resources distinguishable from others and is used for naming resources"
  type        = string
}

variable "domain_name" {
  type        = string
  description = "The name of your domain, this must be set up as a zone in your cloud provider account"
}

variable "vpc" {
  type = object({
    availability_zone_names = list(string)
    vpc_id                  = string
    subnet_ids              = list(string)
  })
}

variable "db_instance_class" {
  type        = string
  description = "Determines the size of the database"
  default     = "db.t3.micro"
}

variable "create_database" {
  type        = bool
  description = "Whether to create a database or not"
  default     = false
}