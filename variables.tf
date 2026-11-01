variable "project" {
  type        = string
  description = "The name of the project."
  default     = "school-web"
}
variable "region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "ap-southeast-1"
}
variable "environment" {
  type        = string
  description = "The environment for the deployment (e.g., dev, staging, prod)."
  default     = "dev"
}
variable "managed_by" {
  type        = string
  description = "The entity managing the resources."
  default     = "terraform"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The IPv4 CIDR block for the VPC."
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidr_blocks" {
  type        = list(string)
  description = "IPv4 CIDR blocks for the public subnets to create (one per AZ)."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets separated by tier (one per AZ per tier)."
  type = object({
    app = list(string)
    db  = list(string)
  })
}
variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for the subnets (one subnet per AZ, per tier). Must be updated when region changes."
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "enable_flow_logs" {
  type        = bool
  description = "Whether to create VPC flow logs delivered to CloudWatch Logs."
  default     = true
}
variable "flow_logs_retention_days" {
  type        = number
  description = "Number of days to retain VPC flow logs in CloudWatch Logs."
  default     = 365
}
variable "gateway_vpc_endpoints" {
  type        = set(string)
  description = "Gateway VPC endpoint services to create and attach to private route tables."
  default     = ["s3", "dynamodb"]
}
variable "nacl_static_rules" {
  description = "NACL rules with a fixed CIDR block per tier. Empty means no rules (deny all)."
  type = map(list(object({
    id          = string
    rule_number = number
    egress      = bool
    protocol    = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
    icmp_type   = optional(number)
    icmp_code   = optional(number)
    rule_action = optional(string, "allow")
  })))
  default = {}
}
variable "nacl_dynamic_rules" {
  description = "NACL rules that iterate over a subnet group's CIDRs. Empty means no rules (deny all)."
  type = map(list(object({
    id           = string
    rule_number  = number
    egress       = bool
    protocol     = string
    subnet_group = string
    from_port    = optional(number)
    to_port      = optional(number)
    icmp_type    = optional(number)
    icmp_code    = optional(number)
    rule_action  = optional(string, "allow")
  })))
  default = {}
}
