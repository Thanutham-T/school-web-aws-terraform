data "aws_region" "current" {}

# Keeps S3 and DynamoDB traffic inside the VPC, avoiding NAT data charges.
resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_vpc_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private : route_table.id]

  tags = merge(var.tags, {
    Name = "${var.project}-${each.key}-gateway-endpoint"
  })
}
