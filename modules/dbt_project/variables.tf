variable "tenant_id" {
  type = string
}

variable "vpc" {
  type = object({
    availability_zone_names = list(string)
    vpc_id                  = string
    subnet_ids              = list(string)
  })
}

variable "dbt_project" {
  type = object({
    github = object({
      org  = string
      repo = string
    })
    snowflake_account_id = string
  })
}

variable "db_instance_id" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "domain_name" {
  type = string
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
