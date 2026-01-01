# Root provider.tf

# Primary Region
provider "aws" {
  region = "eu-west-1"
  profile = "terra"
}

# Secondary/DR Region
provider "aws" {
  alias  = "dr_region"
  region = "eu-west-2"
  profile = "terra" 
}