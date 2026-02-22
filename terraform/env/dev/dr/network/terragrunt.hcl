# This tells this module to inherit the generate block and state logic from root
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/network"
}

# Load module-specific variables
locals {
  module_vars = yamldecode(file("env_vars.yaml"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  # Network defaults
  #locals matrix for natgw vs nat instance
  #Prod-Primary 2 NATGW
  #Prod-DR 1 NATGW
  #Dev-Primary 1 NAT Instance
  #Dev-DR 1 NAT Instance
}

inputs = {
  is_dr = local.region_vars.locals.is_dr
  env_prod = local.region_vars.locals.env_prod
  nat_gw_count = local.region_vars.locals.env_prod ? (local.region_vars.locals.is_dr ? 1 : 2) : 0
  nat_instance_count = local.region_vars.locals.env_prod ? 0 : 1
  cidr_block = local.module_vars.cidr_block
  private_availability_zones = local.module_vars.private_availability_zones
  public_availability_zones = local.module_vars.public_availability_zones
  private_cidr_blocks = local.module_vars.private_cidr_blocks
  public_cidr_blocks = local.module_vars.public_cidr_blocks
  nat_ami = local.module_vars.nat_ami
  nat_instance_type = local.module_vars.nat_instance_type
}