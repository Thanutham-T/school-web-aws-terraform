## Project metadata 
variable "project" {
  type        = string
  description = "The name of the project."
  default     = "school-web"
}

## Network variables
variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidr_blocks" {
  type        = list(string)
  description = "A list of CIDR blocks for the public subnets."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets separated by tier."
  type = object({
    app = list(string)
    db  = list(string)
  })
}
variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones for the subnets."
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

