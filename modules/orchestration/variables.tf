variable "vpc" {
  type = object({
    availability_zone_names = list(string)
    vpc_id                  = string
    subnet_ids              = list(string)
  })
}

variable "db_instance_id" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "airbyte_security_group_id" {
  type = string
}

variable "snowflake_account_id" {
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
