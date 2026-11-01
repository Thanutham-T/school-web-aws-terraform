module "network" {
  source = "./modules/network"

  project                    = var.project
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  availability_zones         = var.availability_zones

  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = var.flow_logs_retention_days
  gateway_vpc_endpoints    = var.gateway_vpc_endpoints

  nacl_static_rules  = var.nacl_static_rules
  nacl_dynamic_rules = var.nacl_dynamic_rules
}

module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id
  security_groups_rules = var.security_groups_rules
}