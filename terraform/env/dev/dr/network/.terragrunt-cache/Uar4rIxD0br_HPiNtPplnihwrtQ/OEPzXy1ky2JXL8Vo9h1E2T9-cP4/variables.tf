variable "env_prod" {
  type = bool
  default = true
}

variable "cidr_block" {
    type = string
    default = "192.168.0.0/16"
}

variable "availability_zone_pri1" {
    type = string
    default = "eu-west-1a"
}

variable "availability_zone_pri2" {
    type = string
    default = "eu-west-1b"
}

variable "availability_zone_pub1" {
    type = string
    default = "eu-west-1c"
}

variable "availability_zone_pub2" {
    type = string
    default = "eu-west-1d"
}

variable "private1_cidr_block" {
    type = string
    default = "192.168.1.0/24"
}

variable "private2_cidr_block" {
    type = string
    default = "192.168.2.0/24"
}

variable "public1_cidr_block" {
    type = string
    default = "192.168.3.0/24"
}

variable "public2_cidr_block" {
    type = string
    default = "192.168.4.0/24"
}
