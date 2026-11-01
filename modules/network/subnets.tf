locals {
  public_subnets = {
    for idx, cidr in var.public_subnet_cidr_blocks :
    cidr => var.availability_zones[idx]
  }

  app_subnets = {
    for idx, cidr in var.private_subnet_cidr_blocks.app :
    cidr => {
      az   = var.availability_zones[idx]
      tier = "app"
    }
  }

  db_subnets = {
    for idx, cidr in var.private_subnet_cidr_blocks.db :
    cidr => {
      az   = var.availability_zones[idx]
      tier = "db"
    }
  }

  all_private_subnets = merge(local.app_subnets, local.db_subnets)
}

# Inputs are validated to have one CIDR per AZ, so the index maps directly
# to an AZ without a modulo fallback that could stack subnets in one AZ.
resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.project}-public-${each.value}"
    Tier = "public"
  })
}

# Same one-CIDR-per-AZ guarantee as the public subnets.
resource "aws_subnet" "private" {
  for_each                = local.all_private_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.project}-${each.value.tier}-${each.value.az}"
    Tier = each.value.tier
  })
}
