data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-name"
    values = ["${var.region}${var.zone_suffix[0]}", "${var.region}${var.zone_suffix[1]}"]
  }
}

module "network" {
  source = "./modules/network"

  project                    = var.project
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  availability_zones         = data.aws_availability_zones.available.names

}
  