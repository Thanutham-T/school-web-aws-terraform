# All outputs below constitute the module's public contract.
# They are retained even if not currently consumed by the root configuration.
# ------------------------------------------------------------------
# Output: vpc_id
# Description: The ID of the VPC.
# Consumers: Other modules (security, compute, etc.) needing the VPC ID.
# ------------------------------------------------------------------
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

# ------------------------------------------------------------------
# Output: internet_gateway_id
# Description: The ID of the Internet Gateway attached to the VPC.
# Consumers: Modules that need to reference the IGW (e.g., VPN, peering).
# ------------------------------------------------------------------
output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

# ------------------------------------------------------------------
# Output: nat_gateway_id
# Description: The ID of the NAT gateway for private subnet egress.
# Consumers: Modules that may need the NAT GW ID (e.g., monitoring).
# ------------------------------------------------------------------
output "nat_gateway_id" {
  description = "The ID of the NAT gateway."
  value       = aws_nat_gateway.this.id
}

# ------------------------------------------------------------------
# Output: public_subnet_ids
# Description: List of public subnet IDs.
# Consumers: Compute modules launching public workloads.
# ------------------------------------------------------------------
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

# ------------------------------------------------------------------
# Output: private_subnet_ids
# Description: List of private subnet IDs (app + db tiers).
# Consumers: Compute modules launching private workloads.
# ------------------------------------------------------------------
output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

# ------------------------------------------------------------------
# Output: subnet_ids
# Description: List of all public and private subnet IDs.
# Consumers: Modules that need every subnet in the VPC.
# ------------------------------------------------------------------
output "subnet_ids" {
  description = "List of IDs of all public and private subnets."
  value = concat(
    [for subnet in aws_subnet.public : subnet.id],
    [for subnet in aws_subnet.private : subnet.id]
  )
}

# ------------------------------------------------------------------
# Output: public_route_table_id
# Description: The ID of the public route table.
# Consumers: Advanced networking modules needing explicit RT association.
# ------------------------------------------------------------------
output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Output: private_route_table_id
# Description: The ID of the private route table.
# Consumers: Advanced networking modules needing explicit RT association.
# ------------------------------------------------------------------
output "private_route_table_id" {
  description = "The ID of the private route table."
  value       = aws_route_table.private.id
}
