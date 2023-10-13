variable "spot_fleet_tagging_role_name" {
  description = "The name of the role that will be used to tag spot fleet instances, we will use it to construct role ARN"
  type        = string
}

variable "tracker_id" {
  description = "reference_id that should be included in names for each of the created resources"
  type        = string
}

variable "ssh_key_name" {
  description = "ssh_key_name to be used when creating instances. It is the output of aws_key_pair.<var-name>.key_name"
  type        = string
}

variable "node_name" {
  description = "spot fleet node name"
  type        = string
}

variable "availability_zone" {
  description = "availability zone in which to create the node"
  type        = string
}

variable "ami" {
  description = "aws ami"
  type        = string
}

variable "root_volume_size" {
  description = "root volume size for each of the nodes in this nodepool"
  type        = number
}

variable "root_volume_type" {
  description = "root volume type for each of the nodes in this nodepool"
  type        = string
  default     = "gp3"
}

variable "security_groups" {
  description = "security groups for all nodes in this nodepool"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "iam instance profile for all nodes in this nodepool"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "user data"
  type        = string
}

variable "cpu_node" {
  description = "specs for cpu node"
  type        = object({
    vcpu = object({
      min = number
      max = number
    })
    memory_per_vcpu = object({
      min = number
      max = number
    })
  })
  default = null
}

variable "gpu_node" {
  description = "specs for gpu node"
  type        = object({
    instance_types = list(string)
  })
  default = null
}

#check "either_cpu_or_gpu_node" {
#  assert {
#    condition     = (var.cpu_node == null && var.gpu_node != null) || (var.cpu_node != null && var.gpu_node == null)
#    error_message = "a node can be either a cpu_node or a gpu_node, only one of them can be set at once"
#  }
#}
#
#check "satisifies_minimum_root_volume_size" {
#  assert {
#    error_message = "when node is nvidia gpu enabled, root volume size must be greater than 75GiB, otherwise greater than 50Gi"
#    condition     = var.root_volume_size >= (var.gpu_node != null ? 75 : 50)
#  }
#}

variable "last_recreated_at" {
  description = "timestamp when this resource was last recreated, whenever this value changes instance is recreated"
  type        = number
  default     = 0
}

#variable "node_props" {
#  description = "node props"
#  type        = object({
#    vcpu = optional(object({
#      min = number
#      max = number
#    }))
#    memory_per_vcpu = optional(object({
#      min = number
#      max = number
#    }))
#
#    nvidia_gpu = optional(object({
#      enabled        = bool
#      instance_types = list(string)
#    }))
#  })
#
#  validation {
#    error_message = "For each spot node configuration, it ensures that if nvidia_gpu is not defined or is enabled, there are valid instance types; and if the nvidia_gpu is either not defined or is disabled, both vCPU and memory per vCPU are specified."
#    condition     = alltrue([
#      var.node_props.nvidia_gpu == null || (var.node_props.nvidia_gpu.enabled && length(var.node_props.nvidia_gpu.instance_types) > 0),
#      (var.node_props.nvidia_gpu == null || !var.node_props.nvidia_gpu.enabled) && var.node_props.vcpu != null && var.node_props.memory_per_vcpu != null,
#    ])
#  }
#}