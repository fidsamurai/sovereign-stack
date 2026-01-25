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
