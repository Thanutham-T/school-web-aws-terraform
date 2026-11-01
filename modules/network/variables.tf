variable "project" {
  type        = string
  description = "The name of the project."
  default     = "school-web"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources. Merged with the module's Name tags."
  default     = {}
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  type        = list(string)
  description = "A list of CIDR blocks for the public subnets. Must contain exactly one CIDR per availability zone."

  default = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidr_blocks) == length(var.availability_zones)
    error_message = "public_subnet_cidr_blocks must contain exactly one CIDR block per entry in availability_zones."
  }
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets separated by tier. Each tier must contain exactly one CIDR per availability zone."
  type = object({
    app = list(string)
    db  = list(string)
  })

  validation {
    condition = (
      length(var.private_subnet_cidr_blocks.app) == length(var.availability_zones) &&
      length(var.private_subnet_cidr_blocks.db) == length(var.availability_zones)
    )
    error_message = "private_subnet_cidr_blocks.app and private_subnet_cidr_blocks.db must each contain exactly one CIDR block per entry in availability_zones."
  }

  validation {
    condition = length(distinct(concat(
      var.public_subnet_cidr_blocks,
      var.private_subnet_cidr_blocks.app,
      var.private_subnet_cidr_blocks.db,
      ))) == (
      length(var.public_subnet_cidr_blocks) +
      length(var.private_subnet_cidr_blocks.app) +
      length(var.private_subnet_cidr_blocks.db)
    )
    error_message = "All public and private subnet CIDR blocks must be unique."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones for the subnets. One subnet is created per AZ, per tier."
  default     = ["ap-southeast-1a", "ap-southeast-1b"]

  validation {
    condition     = length(var.availability_zones) > 0 && length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "availability_zones must be a non-empty list of unique AZ names."
  }
}

variable "enable_flow_logs" {
  type        = bool
  description = "Whether to create VPC flow logs delivered to a CloudWatch Logs group."
  default     = false
}

variable "flow_logs_traffic_type" {
  type        = string
  description = "The type of traffic to capture in the flow logs."
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be one of ALL, ACCEPT, or REJECT."
  }
}

variable "flow_logs_retention_days" {
  type        = number
  description = "Number of days to retain VPC flow logs in CloudWatch Logs."
  default     = 365

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_logs_retention_days
    )
    error_message = "flow_logs_retention_days must be a value supported by CloudWatch Logs retention."
  }
}

variable "gateway_vpc_endpoints" {
  type        = set(string)
  description = "Gateway VPC endpoint services to create (for example s3 and dynamodb). Attached to every private route table."
  default     = ["s3", "dynamodb"]

  validation {
    condition     = alltrue([for service in var.gateway_vpc_endpoints : contains(["s3", "dynamodb"], service)])
    error_message = "gateway_vpc_endpoints only supports the gateway endpoint services \"s3\" and \"dynamodb\"."
  }
}

# Static rules use fixed CIDRs. By convention they take numbers 100-299;
# ICMP rules use icmp_type/icmp_code instead of ports. An empty map denies all.
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

# Dynamic rules expand to one rule per CIDR in their subnet group ("public",
# "app", "db", or the single "vpc" CIDR used by the Route 53 Resolver). Rule
# numbers 300-999 are conventional; the AZ index is added to each base, so
# space bases at least length(availability_zones) apart. An empty map denies all.
variable "nacl_dynamic_rules" {
  description = "NACL rules that iterate over a subnet group's CIDRs. Empty means no rules (deny all)."
  type = map(list(object({
    id           = string
    rule_number  = number # base number — offset by AZ index automatically
    egress       = bool
    protocol     = string
    subnet_group = string # references local.subnet_cidrs key
    from_port    = optional(number)
    to_port      = optional(number)
    icmp_type    = optional(number)
    icmp_code    = optional(number)
    rule_action  = optional(string, "allow")
  })))

  default = {}
}
