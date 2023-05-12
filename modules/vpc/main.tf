#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

# One can use IPAM to automatically asisgn CIDR Blocks thoughout the organization
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#ipv4_ipam_pool_id
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  #  enable_dns_support = true

  tags = {
    Name = var.environment_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  for_each   = { for idx, az in data.aws_availability_zones.available.names : az => idx }
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.${(each.value + 1) * 2}.0/24"

  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name} - public ${each.key}"
  }
}
resource "aws_subnet" "private" {
  for_each   = { for idx, az in data.aws_availability_zones.available.names : az => idx }
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.${(each.value + 1) * 2 - 1}.0/24"

  availability_zone = each.key

  tags = {
    Name = "${var.environment_name} - private ${each.key}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name} - GW"
  }
}

resource "aws_nat_gateway" "example" {

  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name = "${var.environment_name} gw NAT - ${each.key}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public
  vpc      = true

  tags = {
    Name = "${var.environment_name} NAT EIP - ${each.key}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.environment_name} - Public Routes"
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
    Name = "${var.environment_name} - Private Routes ${each.key}"
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