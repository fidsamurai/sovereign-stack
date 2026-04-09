include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # This tells this module to inherit the generate block and state logic from root
  source = "../../../../modules/asg"
}

# Load module-specific variables
locals {
  module_vars = yamldecode(file("env_vars.yaml"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  is_prod = local.region_vars.locals.env_prod
  is_dr = local.region_vars.locals.is_dr

  final_domain = "${local.is_prod ? "prod" : "dev"}-${local.is_dr ? "dr" : "pri"}-oidc-${local.module_vars.domain}"
}

dependency "network" {
  config_path = "../network"
}

inputs = {
  is_dr = local.is_dr
  env_prod = local.is_prod
  region = local.region_vars.locals.region
  asg-cplane-min-memory-mib = local.module_vars.asg-cplane-min-memory-mib
  asg-cplane-max-memory-mib = local.module_vars.asg-cplane-max-memory-mib
  asg-cplane-min-vcpu-count = local.module_vars.asg-cplane-min-vcpu-count
  asg-cplane-max-vcpu-count = local.module_vars.asg-cplane-max-vcpu-count
  asg-workers-min-memory-mib = local.module_vars.asg-workers-min-memory-mib
  asg-workers-max-memory-mib = local.module_vars.asg-workers-max-memory-mib
  asg-workers-min-vcpu-count = local.module_vars.asg-workers-min-vcpu-count
  asg-workers-max-vcpu-count = local.module_vars.asg-workers-max-vcpu-count
  domain = local.module_vars.domain
  final_domain = local.final_domain

  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  public_subnet_ids = dependency.network.outputs.public_subnet_ids
  cplane-sg-id = dependency.network.outputs.cplane-sg-id
  workers-sg-id = dependency.network.outputs.workers-sg-id
  jump-sg-id = dependency.network.outputs.jump-sg-id
  
}