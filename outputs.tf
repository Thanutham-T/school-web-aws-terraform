output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = module.network.vpc_cidr_block
}

output "availability_zones" {
  description = "The availability zones used for the subnets."
  value       = module.network.availability_zones
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (app + db tiers)."
  value       = module.network.private_subnet_ids
}

output "app_subnet_ids" {
  description = "Map of app-tier subnet IDs keyed by CIDR block."
  value       = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Map of db-tier subnet IDs keyed by CIDR block."
  value       = module.network.db_subnet_ids
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = module.network.public_route_table_id
}

output "private_route_table_ids" {
  description = "Map of private route table IDs keyed by tier."
  value       = module.network.private_route_table_ids
}

output "nat_gateway_id" {
  description = "The ID of the NAT gateway."
  value       = module.network.nat_gateway_id
}

output "nacl_ids" {
  description = "Map of network ACL IDs keyed by tier."
  value       = module.network.nacl_ids
}

output "gateway_endpoint_ids" {
  description = "Map of gateway VPC endpoint IDs keyed by service."
  value       = module.network.gateway_endpoint_ids
}

output "flow_log_id" {
  description = "The ID of the VPC flow log, if enabled."
  value       = module.network.flow_log_id
}
