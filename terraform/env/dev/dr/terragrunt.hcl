# 1. Include the root for remote state and global settings
include "root" {
  path = find_in_parent_folders()
}

# 2. Include the region for region specific settings
locals {
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  aws_region   = locals.region_vars.region
  aws_profile  = locals.region_vars.profile 
}

# 3. Generate the provider.tf file
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile}"
}
EOF
}