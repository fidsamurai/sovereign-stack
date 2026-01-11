variable "lt_cplane_iam_instance_profile" {
    type = string
}

variable "asg-cplane-min-memory-mib" {
    type = number
    default = 2048
}

variable "asg-cplane-max-memory-mib" {
    type = number
    default = 4096
}

variable "asg-cplane-min-vcpu-count" {
    type = number
    default = 2
}

variable "asg-cplane-max-vcpu-count" {
    type = number
    default = 4
}

variable "token" {
    type = string
}

variable "discovery_sha" {
    type = string
}