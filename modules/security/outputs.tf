output "security_group_ids" {
  description = "Map of security group IDs keyed by the input security group key."
  value       = { for key, security_group in aws_security_group.this : key => security_group.id }
}
