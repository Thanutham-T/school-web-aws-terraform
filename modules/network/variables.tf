# ------------------------------------------------------------------
# Variable: project
# Purpose: Name of the project, used as prefix for resource naming.
# Type: string
# Default: "school-web"
# ------------------------------------------------------------------
variable "project" {
  type        = string
  description = "The name of the project."
  default     = "school-web"
}

# ------------------------------------------------------------------
# Variable: vpc_cidr_block
# Purpose: CIDR block for the VPC.
# Type: string
# Default: "10.0.0.0/16"
# ------------------------------------------------------------------
variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

# ------------------------------------------------------------------
# Variable: public_subnet_cidr_blocks
# Purpose: List of CIDR blocks for public subnets (one per AZ).
# Type: list(string)
# Default: ["10.0.1.0/24", "10.0.2.0/24"]
# ------------------------------------------------------------------
variable "public_subnet_cidr_blocks" {
  type        = list(string)
  description = "A list of CIDR blocks for the public subnets."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# ------------------------------------------------------------------
# Variable: private_subnet_cidr_blocks
# Purpose: Map of private subnet CIDR blocks per tier (app, db).
# Type: object({ app = list(string), db = list(string) })
# Required: true (no default)
# ------------------------------------------------------------------
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets separated by tier."
  type = object({
    app = list(string)
    db  = list(string)
  })
}

# ------------------------------------------------------------------
# Variable: availability_zones
# Purpose: List of AZ names to distribute subnets across.
# Type: list(string)
# Default: ["ap-southeast-1a", "ap-southeast-1b"]
# ------------------------------------------------------------------
variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones for the subnets."
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# ------------------------------------------------------------------
# Variable: nacl_static_rules
# Purpose: Rules with a fixed CIDR (e.g. 0.0.0.0/0)
# ------------------------------------------------------------------
variable "nacl_static_rules" {
  description = "NACL rules with a fixed CIDR block per tier"
  type = map(list(object({
    id          = string
    rule_number = number
    egress      = bool
    protocol    = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  })))

  default = {
    "public" = [
      # Inbound
      { id = "in_https_anywhere",    rule_number = 100, egress = false, protocol = "tcp", cidr_block = "0.0.0.0/0", from_port = 443,  to_port = 443   },
      { id = "in_ephemeral",         rule_number = 110, egress = false, protocol = "tcp", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 },
      # Outbound
      { id = "out_https_anywhere",   rule_number = 110, egress = true,  protocol = "tcp", cidr_block = "0.0.0.0/0", from_port = 443,  to_port = 443   },
      { id = "out_ephemeral",        rule_number = 120, egress = true,  protocol = "tcp", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 },
    ],
    "app" = [
      # Outbound
      { id = "out_https_anywhere",   rule_number = 100, egress = true,  protocol = "tcp", cidr_block = "0.0.0.0/0", from_port = 443,  to_port = 443   },
    ],
    "db" = []
  }
}

# ------------------------------------------------------------------
# Variable: nacl_dynamic_rules
# Purpose: Rules that expand per-subnet CIDR (one rule per AZ)
# ------------------------------------------------------------------
variable "nacl_dynamic_rules" {
  description = "NACL rules that iterate over a subnet group's CIDRs"
  type = map(list(object({
    id           = string
    rule_number  = number  # base number — offset by AZ index automatically
    egress       = bool
    protocol     = string
    subnet_group = string  # references local.subnet_cidrs key
    from_port    = number
    to_port      = number
  })))

  default = {
    "public" = [
      # Outbound
      { id = "out_http_to_app",      rule_number = 100, egress = true,  protocol = "tcp", subnet_group = "app",    from_port = 80,   to_port = 80    },
    ],
    "app" = [
      # Inbound
      { id = "in_http_from_public",  rule_number = 100, egress = false, protocol = "tcp", subnet_group = "public", from_port = 80,   to_port = 80    },
      { id = "in_eph_from_public",   rule_number = 110, egress = false, protocol = "tcp", subnet_group = "public", from_port = 1024, to_port = 65535 },
      { id = "in_eph_from_db",       rule_number = 120, egress = false, protocol = "tcp", subnet_group = "db",     from_port = 1024, to_port = 65535 },
      # Outbound
      { id = "out_mysql_to_db",      rule_number = 110, egress = true,  protocol = "tcp", subnet_group = "db",     from_port = 3306, to_port = 3306  },
      { id = "out_eph_to_public",    rule_number = 120, egress = true,  protocol = "tcp", subnet_group = "public", from_port = 1024, to_port = 65535 },
    ],
    "db" = [
      # Inbound
      { id = "in_mysql_from_app",    rule_number = 100, egress = false, protocol = "tcp", subnet_group = "app",    from_port = 3306, to_port = 3306  },
      # Outbound
      { id = "out_eph_to_app",       rule_number = 100, egress = true,  protocol = "tcp", subnet_group = "app",    from_port = 1024, to_port = 65535 },
    ]
  }
}
