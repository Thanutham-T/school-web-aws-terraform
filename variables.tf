## Project metadata
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
variable "zone_suffix" {
  type        = list(string)
  description = "The suffix for the availability zone."
  default     = ["a", "b"]
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

## Network modules
variable "vpc_cidr_block" {
  type        = string
  description = "The IPv4 CIDR block for the VPC."
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidr_blocks" {
  type        = list(string)
  description = "IPv4 CIDR blocks for the public subnets to create."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets separated by tier."
  type = object({
    app = list(string)
    db  = list(string)
  })
}
