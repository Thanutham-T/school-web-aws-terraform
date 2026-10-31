# Create the VPC with DNS resolution and DNS hostnames enabled.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.project}-vpc"
  }
}

# Attach an Internet Gateway to the VPC. Public internet access also requires
# a route table that directs internet-bound traffic to this gateway.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-igw"
  }
}

resource "aws_nat_gateway" "this" {
  connectivity_type = "public"
  availability_mode = "regional"
  vpc_id            = aws_vpc.this.id

  tags = {
    Name = "${var.project}-rnat-gateway"
  }

  depends_on = [aws_internet_gateway.this]
}

# Assign subnet CIDRs to availability zones in order, cycling through the AZs
# when there are more subnet CIDRs than configured availability zones.
locals {
  public_subnets = {
    for idx, cidr in var.public_subnet_cidr_blocks :
    cidr => var.availability_zones[idx % length(var.availability_zones)]
  }

  app_subnets = {
    for idx, cidr in var.private_subnet_cidr_blocks.app :
    cidr => {
      az   = var.availability_zones[idx % length(var.availability_zones)],
      tier = "app"
    }
  }

  db_subnets = {
    for idx, cidr in var.private_subnet_cidr_blocks.db :
    cidr => {
      az   = var.availability_zones[idx % length(var.availability_zones)],
      tier = "db"
    }
  }

  all_private_subnets = merge(local.app_subnets, local.db_subnets)
}

# Public subnets assign public IPv4 addresses to instances at launch.
# Internet connectivity still depends on the VPC route-table configuration.
resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-public-subnet-${each.key}"
  }
}

# Private subnets do not assign public IPv4 addresses at launch. Their routing
# and any outbound access should be controlled by the associated route tables.
resource "aws_subnet" "private" {
  for_each                = local.all_private_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-private-subnet-${each.value.tier}-${each.key}"
    Tier = each.value.tier
  }
}

# Route tables define how traffic is directed within the VPC.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project}-public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.project}-private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# The default security group is created automatically by AWS for each VPC. It allows all inbound and outbound traffic by default, which may not be desirable for security reasons. This resource explicitly defines a default security group with no ingress or egress rules, effectively locking it down.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = {
    Name = "DO NOT USE - locked down default SG"
  }
}