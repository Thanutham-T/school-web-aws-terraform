# #   Remote state is required for anything beyond a single developer.
# #   Uncomment, create the bucket (versioned + encrypted + locked down),
# #   then run: terraform init -migrate-state
# terraform {
#   backend "s3" {
#     bucket       = "CHANGE-ME-terraform-state"
#     key          = "school-web/dev/network/terraform.tfstate"
#     region       = "ap-southeast-1"
#     encrypt      = true
#     use_lockfile = true # native S3 locking, Terraform >= 1.10
#   }
# }