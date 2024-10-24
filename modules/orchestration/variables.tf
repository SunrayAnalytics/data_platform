variable "vpc" {
  type = object({
    availability_zone_names = list(string)
    vpc_id                  = string
    subnet_ids              = list(string)
  })
}

variable "tenant_id" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "airbyte_instances" {
  type = list(object({
    instance_type = string
    classifier    = string
  }))
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

variable "dbt_projects" {
  type = list(object({
    github = object({
      org  = string
      repo = string
    })
    snowflake_account_id = string
  }))
}

variable "bastion_instance_id" {
  type        = string
  description = "This is needed for the local provisioner to reach the database"
}
