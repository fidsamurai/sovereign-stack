# Root provider.tf

# Primary Region
provider "aws" {
  region = "eu-west-1"
}

# Secondary/DR Region
provider "aws" {
  alias  = "dr_region"
  region = "eu-west-2" 
}