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

