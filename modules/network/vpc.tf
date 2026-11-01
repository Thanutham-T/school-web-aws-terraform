resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = merge(var.tags, {
    Name = "${var.project}-vpc"
  })
}

# The default SG cannot be deleted, so lock it down instead.
# This also satisfies CKV2_AWS_12.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name = "${var.project}-DO-NOT-USE-default-sg"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-igw"
  })
}

# Regional mode lets AWS manage the NAT EIPs and expand across AZs.
# If a downstream system allowlists NAT egress IPs, switch to per-AZ
# EIPs and export nat_gateway_public_ips.
resource "aws_nat_gateway" "this" {
  connectivity_type = "public"
  availability_mode = "regional"
  vpc_id            = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-nat-gateway"
  })

  depends_on = [aws_internet_gateway.this]
}
