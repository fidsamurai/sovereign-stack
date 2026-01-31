variable "env_prod" {
  type = bool
  default = true
}

variable "cidr_block" {
    type = string
    default = "192.168.0.0/16"
}

variable "private_availability_zones" {
    type = list(string)
    default = ["eu-west-1a", "eu-west-1b"]
}

variable "public_availability_zones" {
    type = list(string)
    default = ["eu-west-1c", "eu-west-1d"]
}

variable "private_cidr_blocks" {
    type = list(string)
    default = ["192.168.1.0/24", "192.168.2.0/24"]
}

variable "public_cidr_blocks" {
    type = list(string)
    default = ["192.168.3.0/24", "192.168.4.0/24"]
}

variable "nat_ami" {
    type = string
    default = "ami-0c55b159cbfafe1f0"
}

variable "nat_instance_type" {
    type = string
    default = "t4g.micro"
}
