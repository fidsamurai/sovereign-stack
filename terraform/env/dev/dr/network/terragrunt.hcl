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
}

inputs = {
  # Network defaults
   cidr_block = local.module_vars.cidr_block
   private_availability_zones = local.module_vars.private_availability_zones
   public_availability_zones = local.module_vars.public_availability_zones
   private_cidr_blocks = local.module_vars.private_cidr_blocks
   public_cidr_blocks = local.module_vars.public_cidr_blocks
   nat_ami = local.module_vars.nat_ami
   nat_instance_type = local.module_vars.nat_instance_type
}
