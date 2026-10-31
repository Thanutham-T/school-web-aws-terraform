# ------------------------------------------------------------------
# Provider versions for the network module
# Terraform >= 1.17.1
# AWS provider >= 6.71.0 (hashicorp/aws)
# ------------------------------------------------------------------
terraform {
  required_version = ">= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.71.0"
    }
  }
}
