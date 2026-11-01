output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "The availability zones used by the module."
  value       = var.availability_zones
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT gateway."
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT gateway, when exposed by the provider."
  value       = aws_nat_gateway.this.public_ip != null ? [aws_nat_gateway.this.public_ip] : []
}

# Flat lists are compatibility aliases; prefer the keyed maps.
output "public_subnet_ids" {
  description = "List of public subnet IDs (compatibility alias)."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnet_ids_by_cidr" {
  description = "Map of public subnet IDs keyed by CIDR block."
  value       = { for cidr, subnet in aws_subnet.public : cidr => subnet.id }
}

output "public_subnet_ids_by_az" {
  description = "Map of public subnet IDs keyed by availability zone."
  value       = { for cidr, subnet in aws_subnet.public : local.public_subnets[cidr] => subnet.id }
}

output "app_subnet_ids" {
  description = "Map of app-tier private subnet IDs keyed by CIDR block."
  value       = { for cidr, subnet in aws_subnet.private : cidr => subnet.id if local.all_private_subnets[cidr].tier == "app" }
}

output "app_subnet_ids_by_az" {
  description = "Map of app-tier private subnet IDs keyed by availability zone."
  value       = { for cidr, subnet in aws_subnet.private : local.all_private_subnets[cidr].az => subnet.id if local.all_private_subnets[cidr].tier == "app" }
}

output "db_subnet_ids" {
  description = "Map of db-tier private subnet IDs keyed by CIDR block."
  value       = { for cidr, subnet in aws_subnet.private : cidr => subnet.id if local.all_private_subnets[cidr].tier == "db" }
}

output "db_subnet_ids_by_az" {
  description = "Map of db-tier private subnet IDs keyed by availability zone."
  value       = { for cidr, subnet in aws_subnet.private : local.all_private_subnets[cidr].az => subnet.id if local.all_private_subnets[cidr].tier == "db" }
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (compatibility alias)."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnet_ids_by_cidr" {
  description = "Map of all private subnet IDs keyed by CIDR block."
  value       = { for cidr, subnet in aws_subnet.private : cidr => subnet.id }
}

output "subnet_ids" {
  description = "List of IDs of all public and private subnets."
  value = concat(
    [for subnet in aws_subnet.public : subnet.id],
    [for subnet in aws_subnet.private : subnet.id]
  )
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Map of private route table IDs keyed by tier."
  value       = { for tier, route_table in aws_route_table.private : tier => route_table.id }
}

output "private_route_table_id" {
  description = "Deprecated: ID of the app-tier private route table. Use private_route_table_ids instead."
  value       = aws_route_table.private["app"].id
}

output "nacl_ids" {
  description = "Map of network ACL IDs keyed by tier (public, app, db)."
  value       = { for tier, nacl in aws_network_acl.this : tier => nacl.id }
}

output "gateway_endpoint_ids" {
  description = "Map of gateway VPC endpoint IDs keyed by service (s3, dynamodb)."
  value       = { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.id }
}

output "flow_log_id" {
  description = "The ID of the VPC flow log, if enabled."
  value       = var.enable_flow_logs ? aws_flow_log.this[0].id : null
}
