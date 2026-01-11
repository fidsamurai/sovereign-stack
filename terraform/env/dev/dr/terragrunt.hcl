include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/network"
  source = "../../../modules/lt-asg"
  source = "../../../modules/alb"
  source = "../../../modules/rds"
  source = "../../../modules/s3-cloudfront"
  source = "../../../modules/route53"
}

inputs = {
  env_prod   = false
  aws_region = "eu-west-1"
  
  # Network defaults
   cidr_block = "192.168.0.0/16"
   availability_zone_pri1 = "eu-west-1a"
   availability_zone_pri2 = "eu-west-1b"
   availability_zone_pub1 = "eu-west-1c"
   availability_zone_pub2 = "eu-west-1d"
   private1_cidr_block = "192.168.1.0/24"
   private2_cidr_block = "192.168.2.0/24"
   public1_cidr_block = "192.168.3.0/24"
   public2_cidr_block = "192.168.4.0/24"

  # LT + ASG defaults
   asg_cplane_key_name = "cplane"
   asg_cplane_min_vcpu_count = 2
   asg_cplane_max_vcpu_count = 4
   asg_cplane_min_memory_mib = 2048
   asg_cplane_max_memory_mib = 4096

   token = ""
   discovery_sha = ""
}
