variable "availability_zone" {
  description = "availability zone for nodepool"
  type        = string
}

variable "ami" {
  description = "aws ami to be used for all nodes created in this nodepool"
  type        = string
}

variable "instance_type" {
  description = "aws instance type for this nodepool"
  type        = string
}

variable "security_groups" {
  description = "security groups for all nodes in this nodepool"
  type        = list(string)
}

variable "nvidia_gpu_enabled" {
  description = "is this nodepool nvidia gpu enabled"
  type        = string
}

variable "root_volume_size" {
  description = "root volume size for each of the nodes in this nodepool"
  type        = number

  validation {
    error_message = "when node is nvidia gpu enabled, root volume size must be greater than 75GiB, otherwise greater than 50Gi"
    condition     = var.root_volume_size > (var.nvidia_gpu_enabled ? 75 : 50)
  }
}

variable "root_volume_type" {
  description = "root volume type for each of the nodes in this nodepool"
  type        = string
  default     = "gp3"
}

variable "iam_instance_profile" {
  description = "iam instance profile for all nodes in this nodepool"
  type        = optional(string)
}

variable "nodes" {
  description = "map of nodes to be created in this nodepool"
  type        = map(object({
    recreate = optional(bool)
  }))
}
