packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "workers"
  instance_type = "t4g.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  spot_allocation_strategy = "lowest-price"
}

build {
  name    = "workers"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
}

provisioners {
  type = "shell"
  script = "workers.sh"
}
