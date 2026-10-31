# ------------------------------------------------------------------
# Resource: aws_vpc.this
# Purpose: Create the VPC with DNS resolution and hostnames enabled.
# Compliance: Provides the network boundary for all resources.
# Key arguments: cidr_block, enable_dns_support, enable_dns_hostnames.
# ------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.project}-vpc"
  }
}

# ------------------------------------------------------------------
# Resource: aws_default_security_group.default
# Purpose: Lock down the default security group that AWS creates for the VPC.
# Compliance: Satisfies policy CKV2_AWS_12 (default SG must restrict all traffic).
# Key arguments: vpc_id, empty ingress/egress lists.
# ------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = {
    Name = "DO NOT USE - locked down default SG"
  }
}
# ------------------------------------------------------------------
# Resource: aws_internet_gateway.this
# Purpose: Attach an Internet Gateway to the VPC for public internet access.
# Compliance: Enables outbound internet for public subnets via route table.
# Key arguments: vpc_id.
# ------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# ------------------------------------------------------------------
# Resource: aws_nat_gateway.this
# Purpose: Provide a managed NAT gateway for private subnet outbound internet.
# Compliance: Allows private workloads to reach the internet without inbound access.
# Key arguments: connectivity_type, availability_mode, vpc_id, depends_on IGW.
# ------------------------------------------------------------------
resource "aws_nat_gateway" "this" {
  connectivity_type = "public"
  availability_mode = "regional"
  vpc_id            = aws_vpc.this.id

  tags = {
    Name = "${var.project}-rnat-gateway"
  }

  depends_on = [aws_internet_gateway.this]
}

# ------------------------------------------------------------------
# Locals: subnet mapping helpers
# Purpose: Compute subnet-to-AZ mappings for public, app, and db tiers,
#          and merge private tiers into a single map for iteration.
# Key outputs: public_subnets, app_subnets, db_subnets, all_private_subnets
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Resource: aws_subnet.public
# Purpose: Create public subnets in each AZ with no public IP assignment.
# Compliance: Public subnets must not auto-assign public IPs; routing is via IGW.
# Key arguments: for_each over local.public_subnets, vpc_id, cidr_block, availability_zone, map_public_ip_on_launch.
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Resource: aws_subnet.private
# Purpose: Create private subnets in each AZ for app and db tiers.
# Compliance: Private subnets must not auto-assign public IPs; routing is via NAT gateway.
# Key arguments: for_each over local.all_private_subnets, vpc_id, cidr_block, availability_zone, map_public_ip_on_launch.
# ------------------------------------------------------------------  
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

# ------------------------------------------------------------------
# Resource: aws_route_table.public
# Purpose: Public route table with default route to Internet Gateway.
# Compliance: Enables internet egress for public subnets.
# Key arguments: vpc_id, route to IGW.
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Resource: aws_route_table.private
# Purpose: Private route table with default route to NAT gateway.
# Compliance: Provides controlled outbound internet for private subnets.
# Key arguments: vpc_id, route to NAT gateway.
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Resource: aws_route_table_association.public
# Purpose: Associate each public subnet with the public route table.
# Compliance: Ensures public subnets use IGW route.
# Key arguments: for_each over aws_subnet.public, route_table_id.
# ------------------------------------------------------------------
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Resource: aws_route_table_association.private
# Purpose: Associate each private subnet with the private route table.
# Compliance: Ensures private subnets use NAT gateway route.
# Key arguments: for_each over aws_subnet.private, route_table_id.
# ------------------------------------------------------------------
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
