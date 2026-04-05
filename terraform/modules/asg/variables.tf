variable "is_dr" {
  type        = bool
  description = "Set to true for Disaster Recovery regions"
}

variable "env_prod" {
  type        = bool
  description = "Set to true for Production environments"
}

variable "region" {
  type = string
}

variable "asg-cplane-min-memory-mib" {
    type = number
}

variable "asg-cplane-max-memory-mib" {
    type = number
}

variable "asg-cplane-min-vcpu-count" {
    type = number
}

variable "asg-cplane-max-vcpu-count" {
    type = number
}

variable "asg-workers-min-memory-mib" {
  type = number
}

variable "asg-workers-max-memory-mib" {
  type = number
}

variable "asg-workers-min-vcpu-count" {
  type = number
}

variable "asg-workers-max-vcpu-count" {
  type = number
}

variable "cplane-sg-id" {
  type = string
}

variable "workers-sg-id" {
  type = string
}

variable "jump-sg-id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "final_domain" {
  type = string
}