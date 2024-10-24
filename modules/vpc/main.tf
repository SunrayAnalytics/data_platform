#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

# One can use IPAM to automatically asisgn CIDR Blocks thoughout the organization
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#ipv4_ipam_pool_id
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name   = var.tenant_id
    Tenant = var.tenant_id
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.number_of_azs)
}

resource "aws_subnet" "public" {
  for_each   = { for idx, az in local.selected_azs : az => idx }
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.${(each.value + 1) * 2}.0/24"

  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name   = "${var.tenant_id} - public ${each.key}"
    Tenant = var.tenant_id
  }
}

resource "aws_subnet" "private" {
  for_each   = { for idx, az in local.selected_azs : az => idx }
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.${(each.value + 1) * 2 - 1}.0/24"

  availability_zone = each.key

  tags = {
    Name   = "${var.tenant_id} - private ${each.key}"
    Tenant = var.tenant_id
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name   = "${var.tenant_id} - GW"
    Tenant = var.tenant_id
  }
}

resource "aws_nat_gateway" "example" {

  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name   = "${var.tenant_id} gw NAT - ${each.key}"
    Tenant = var.tenant_id
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public

  tags = {
    Name   = "${var.tenant_id} NAT EIP - ${each.key}"
    Tenant = var.tenant_id
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name   = "${var.tenant_id} - Public Routes"
    Tenant = var.tenant_id
  }
}

resource "aws_route_table" "private_route_table" {
  for_each = aws_nat_gateway.example

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = each.value.id
  }

  tags = {
    Name   = "${var.tenant_id} - Private Routes ${each.key}"
    Tenant = var.tenant_id
  }

  lifecycle {
    # It seems like route tables are forever recreated if we don't ignore the route argument
    ignore_changes = [route]
  }
}

resource "aws_route_table_association" "public_association" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_association" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table[each.key].id
}
