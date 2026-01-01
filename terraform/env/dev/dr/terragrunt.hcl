include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/network"
}

inputs = {
  env_prod   = false
  aws_region = "eu-west-2"
  
  # Network defaults
  # cidr_block = "192.168.0.0/16"
}
