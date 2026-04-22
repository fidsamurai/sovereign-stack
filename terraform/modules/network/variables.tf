variable "is_dr" {
  type        = bool
  description = "Set to true for Disaster Recovery regions"
}

variable "env_prod" {
  type        = bool
  description = "Set to true for Production environments"
}

variable "nat_gw_count" {
  type        = number
  description = "Number of NAT Gateways"
}

variable "nat_instance_count" {
  type        = number
  description = "Number of NAT Instances"
}

variable "cidr_block" {
    type = string
}

variable "private_availability_zones" {
    type = list(string)
}

variable "public_availability_zones" {
    type = list(string)
}

variable "private_cidr_blocks" {
    type = list(string)
}

variable "public_cidr_blocks" {
    type = list(string)
}

variable "nat_instance_type" {
    type = string
}
