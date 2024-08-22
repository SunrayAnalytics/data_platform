variable "environment_name" {
  type = string
}

variable "bucket_name_prefix" {
  type = string
}

variable "lake_administrators" {
  type = list(string)
}
