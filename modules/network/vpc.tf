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
