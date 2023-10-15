variable "ec2_nodepools" {
  type = map(object({
    ami                  = string
    ami_ssh_username     = string
    availability_zone    = string
    instance_type        = string
    nvidia_gpu_enabled   = optional(bool)
    root_volume_size     = string
    root_volume_type     = string
    iam_instance_profile = optional(string)
    nodes                = map(object({
      last_recreated_at = optional(number)
    }))
  }))
}

variable "spot_nodepools" {
  type = map(object({
    ami                          = string
    ami_ssh_username             = string
    availability_zone            = string
    root_volume_size             = string
    root_volume_type             = string
    iam_instance_profile         = optional(string)
    spot_fleet_tagging_role_name = string

    cpu_node = optional(object({
      vcpu = object({
        min = number
        max = number
      })
      memory_per_vcpu = object({
        min = number
        max = number
      })
    }))

    gpu_node = optional(object({
      instance_types = list(string)
    }))

    nodes = map(object({
      last_recreated_at = optional(number)
    }))
  }))

  validation {
    error_message = "a nodepool can be either a cpu_node or a gpu_node, only one of them can be set at once"
    condition     = alltrue([
      for name, config in var.spot_nodepools :
      ((config.cpu_node == null && config.gpu_node != null) || (config.cpu_node != null && config.gpu_node == null))
    ])
  }
}
