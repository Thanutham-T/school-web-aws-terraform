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
