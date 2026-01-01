# Deploy Primary Infrastructure
module "networking_primary" {
  source = "./modules/networking"
  # Uses default eu-west-1 provider
}

# Deploy Pilot Light (DR) Infrastructure
module "networking_dr" {
  source = "./modules/networking"
  providers = {
    aws = aws.london
  }
}