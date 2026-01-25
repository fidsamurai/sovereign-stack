# 1. Include the root for remote state and global settings
include "root" {
  path = find_in_parent_folders()
}

# 2. Include the variable for the module
locals {
  module_vars  = yamldecode(file("env_vars.yaml"))
}

terraform {
  source = "../../../../modules/network"
}

inputs = {
  # Network defaults
   cidr_block = local.module_vars.cidr_block
   availability_zone_pri1 = local.module_vars.availability_zone_pri1
   availability_zone_pri2 = local.module_vars.availability_zone_pri2
   availability_zone_pub1 = local.module_vars.availability_zone_pub1
   availability_zone_pub2 = local.module_vars.availability_zone_pub2
   private1_cidr_block = local.module_vars.private1_cidr_block
   private2_cidr_block = local.module_vars.private2_cidr_block
   public1_cidr_block = local.module_vars.public1_cidr_block
   public2_cidr_block = local.module_vars.public2_cidr_block
}
