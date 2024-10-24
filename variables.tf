#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

# variable "aws_region" { # TODO Figure out whether we actually need this
#   type        = string
#   description = "The region where resources should be provisioned"
# }

variable "tenant_id" {
  type        = string
  description = "A unique identifier for your environment to help distinguish from other resources in your cloud provider account"
}

variable "domain_name" {
  type        = string
  description = "The name of your domain, this must be set up as a zone in your cloud provider account"
}

variable "my_ip" {
  type        = string
  description = "For now just used to set up access"
}

variable "db_instance_class" {
  type        = string
  description = "Determines the size of the database"
  default     = "db.t3.micro"
}

variable "airbyte_instances" {
  type = list(object({
    instance_type = string
    classifier    = string
  }))
}

variable "dbt_projects" {
  type = list(object({
    github = object({
      org  = string
      repo = string
    })
    snowflake_account_id = string
  }))
}

variable "number_of_azs" {
  type    = number
  default = 2
}
