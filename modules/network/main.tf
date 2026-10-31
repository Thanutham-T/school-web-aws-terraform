## =================================================================
## VPC and Default Security Group Resources
## =================================================================

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


## =================================================================
## Internet Gateway and NAT Gateway Resources
## =================================================================

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


## =================================================================
## Subnet Resources
## =================================================================

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


## =================================================================
## Route Table Resources
## =================================================================

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


## =================================================================
## Network ACL Rules 
## =================================================================

## Public Subnet ACL Rules
# ------------------------------------------------------------------
# Resource: aws_network_acl.public
# Purpose: Create a network ACL for public subnets with specific ingress/egress rules.
# Compliance: Provides an additional layer of security for public subnets.
# Key arguments: for_each over aws_subnet.public, vpc_id, subnet_ids.
# ------------------------------------------------------------------
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = keys(local.public_subnets)

  tags = {
    Name = "${var.project}-public-network-acl"
  }
}

## Inbound Rules for Public Subnet ACL
# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_in_https_from_anywhere
# Purpose: Allow inbound HTTPS traffic from anywhere to public subnets. (CloudFront/App_subnet to the ALB)
# Compliance: Enables web traffic to public-facing resources.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_in_https_from_anywhere" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_in_ephemeral_from_anywhere
# Purpose: Allow inbound ephemeral port traffic from anywhere to public subnets. (Internet return to NATGW)
# Compliance: Enables communication with public-facing resources on ephemeral ports.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_in_ephemeral_from_anywhere" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

## Outbound Rules for Public Subnet ACL
# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_out_http_to_app
# Purpose: Allow outbound HTTP traffic from public subnets to app subnets. (ALB to App_subnet)
# Compliance: Enables communication from public-facing resources to app subnets.
# Key arguments: for_each over local.app_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_out_http_to_app" {
  for_each       = local.app_subnets
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100 + index(sort(keys(local.app_subnets)), each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 80
  to_port        = 80
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_out_https_to_anywhere
# Purpose: Allow outbound HTTPS traffic from public subnets to anywhere. (NATGW to Internet)
# Compliance: Enables secure communication from public-facing resources to the internet.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_out_https_to_anywhere" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_out_ephemeral_to_anywhere
# Purpose: Allow outbound ephemeral port traffic from public subnets to anywhere. (Ephemeral return traffic to CloudFront clients)
# Compliance: Enables communication from public-facing resources on ephemeral ports to the internet and app subnets.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_out_ephemeral_to_anywhere" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

## App Subnet ACL Rules
# ------------------------------------------------------------------
# Resource: aws_network_acl.app
# Purpose: Create a network ACL for app subnets with specific ingress/egress rules.
# Compliance: Provides an additional layer of security for app subnets.
# Key arguments: vpc_id, subnet_ids.
# ------------------------------------------------------------------
resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = keys(local.app_subnets)

  tags = {
    Name = "${var.project}-app-network-acl"
  }
}

## Inbound Rules for App Subnet ACL
# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_in_http_from_public
# Purpose: Allow inbound HTTP traffic from public subnets to app subnets. (ALB to App_subnet)
# Compliance: Enables web traffic from public-facing resources to app subnets.
# Key arguments: for_each over var.public_subnet_cidrs, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_in_http_from_public" {
  for_each       = local.public_subnets
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100 + index(sort(keys(local.public_subnets)), each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 80
  to_port        = 80
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_in_ephemeral_from_public
# Purpose: Allow inbound ephemeral port traffic to app subnets from public subnets. (NATGW to App_subnet)
# Compliance: Enables communication to app subnets on ephemeral ports from the internet.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_in_ephemeral_from_public" {
  for_each       = local.public_subnets
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110 + index(sort(keys(local.public_subnets)), each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 1024
  to_port        = 65535
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_in_ephemeral_from_db
# Purpose: Allow inbound ephemeral port traffic from db subnets to app subnets. (NATGW to App_subnet)
# Compliance: Enables communication to app subnets on ephemeral ports from the internet.
# Key arguments: for_each over local.db_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_in_ephemeral_from_db" {
  for_each       = local.db_subnets
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110 + index(sort(keys(local.db_subnets)), each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 1024
  to_port        = 65535
}

## Outbound Rules for App Subnet ACL
# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_out_https_to_anywhere
# Purpose: Allow outbound HTTPS traffic from app subnets to anywhere. (App_subnet to NATGW)
# Compliance: Enables secure communication from app subnets to the internet.
# Key arguments: network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_out_https_to_anywhere" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_out_mysql_to_db
# Purpose: Allow outbound MySQL traffic from app subnets to db subnets. (App_subnet to DB_subnet)
# Compliance: Enables database connectivity from app subnets to db subnets.
# Key arguments: for_each over local.db_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_out_mysql_to_db" {
  for_each       = local.db_subnets
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110 + index(sort(keys(local.db_subnets)), each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 3306
  to_port        = 3306
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.app_out_ephemeral_to_public
# Purpose: Allow outbound ephemeral port traffic from app subnets to public subnets. (Ephemeral return to ALB)
# Compliance: Enables communication from app subnets on ephemeral ports to public subnets.
# Key arguments: for_each over local.public_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "app_out_ephemeral_to_public" {
  for_each       = local.public_subnets
  network_acl_id = aws_network_acl.app.id
  rule_number    = 120 + index(sort(keys(local.public_subnets)), each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 1024
  to_port        = 65535
}

## Database Subnet ACL Rules
# ------------------------------------------------------------------
# Resource: aws_network_acl.db
# Purpose: Create a network ACL for db subnets with specific ingress/egress rules.
# Compliance: Provides an additional layer of security for db subnets.
# Key arguments: vpc_id, subnet_ids.
# ------------------------------------------------------------------
resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = keys(local.db_subnets)
  tags = {
    Name = "${var.project}-db-nacl"
  }
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.db_in_mysql_from_app
# Purpose: Allow inbound MySQL traffic from app subnets to db subnets. (App_subnet to DB_subnet)
# Compliance: Enables database connectivity from app subnets to db subnets.
# Key arguments: for_each over local.app_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "db_in_mysql_from_app" {
  for_each       = local.app_subnets
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100 + index(sort(keys(local.app_subnets)), each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 3306
  to_port        = 3306
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.db_out_ephemeral_to_app
# Purpose: Allow outbound ephemeral port traffic from db subnets to app subnets. (Ephemeral return to App)
# Compliance: Enables communication from db subnets on ephemeral ports to app subnets.
# Key arguments: for_each over local.app_subnets, network_acl_id, rule_number, egress, protocol, rule_action, cidr_block, from_port, to_port.
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "db_out_ephemeral_to_app" {
  for_each       = local.app_subnets
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100 + index(sort(keys(local.app_subnets)), each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 1024
  to_port        = 65535
}
