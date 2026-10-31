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
