locals {
  # app reaches the internet via NAT; db stays isolated (local routes plus gateway VPC endpoints only).
  private_tiers = toset(["app", "db"])
}

# Routes are standalone resources so the route tables stay non-authoritative.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-public-route-table"
  })

}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# One route table per tier so the db tier can stay off the internet.
resource "aws_route_table" "private" {
  for_each = local.private_tiers

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-${each.key}-route-table"
  })
}

# Only the app tier gets a default route to the NAT gateway.
resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.private["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = local.all_private_subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.tier].id
}
