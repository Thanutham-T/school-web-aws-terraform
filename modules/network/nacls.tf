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
  subnet_ids = [for s in aws_subnet.public : s.id]

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
# Resource: aws_network_acl_rule.public_in_ephemeral_from_anywhere_low
# Purpose: Allow inbound ephemeral port traffic (1024-3388) from anywhere to public subnets.
# Compliance: Enables return traffic on ephemeral ports while blocking RDP (3389).
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_in_ephemeral_from_anywhere_low" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 3388
}

# ------------------------------------------------------------------
# Resource: aws_network_acl_rule.public_in_ephemeral_from_anywhere_high
# Purpose: Allow inbound ephemeral port traffic (3390-65535) from anywhere to public subnets.
# Compliance: Enables return traffic on ephemeral ports while blocking RDP (3389).
# ------------------------------------------------------------------
resource "aws_network_acl_rule" "public_in_ephemeral_from_anywhere_high" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 111
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 3390
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
  subnet_ids = [for s in aws_subnet.private : s.id if s.tags.Tier == "app"]

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
  subnet_ids = [for s in aws_subnet.private : s.id if s.tags.Tier == "db"]
  tags = {
    Name = "${var.project}-db-network-acl"
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
