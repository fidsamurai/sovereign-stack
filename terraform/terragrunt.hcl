locals {
  # Recursively find the root terragrunt.hcl
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = var.aws_region
  profile = "terra"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket or local
# Using local for now as per previous implicit configuration, but typically this should be S3.
remote_state {
  backend = "local"
  config = {
    path = "${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
