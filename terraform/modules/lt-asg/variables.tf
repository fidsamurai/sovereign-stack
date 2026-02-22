variable "lt_cplane_iam_instance_profile" {
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

variable "token" {
    type = string
}

variable "discovery_sha" {
    type = string
}