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

variable "bastion_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "The size of the bastion host"
}