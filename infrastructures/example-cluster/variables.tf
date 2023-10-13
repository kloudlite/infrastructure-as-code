variable "aws_region" { type = string }
variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

variable "tracker_id" {
  description = "tracker id, for which this resource is being created"
  type        = string
}

variable "k3s_masters" {
  description = "k3s masters configuration"
  type        = object({
    ami                  = string
    ami_ssh_username     = string
    instance_type        = string
    nvidia_gpu_enabled   = optional(bool)
    root_volume_size     = string
    root_volume_type     = string
    iam_instance_profile = optional(string)
    taint_master_nodes   = bool

    public_dns_host = string

    backup_to_s3 = object({
      enabled = bool

      bucket_name   = optional(string)
      bucket_region = optional(string)
      bucket_folder = optional(string)
    })

    restore_from_latest_snapshot = optional(bool)

    cloudflare = optional(object({
      enabled   = bool
      api_token = optional(string)
      zone_id   = optional(string)
      domain    = optional(string)
    }))

    nodes = map(object({
      role              = string
      availability_zone = string
      last_recreated_at = optional(number)
    }))
  })

  validation {
    error_message = "when backup_to_s3 is enabled, all the following variables must be set: bucket_name, bucket_region, bucket_folder"
    condition     = var.k3s_masters.backup_to_s3.enabled == false || alltrue([
      var.k3s_masters.backup_to_s3.bucket_name != "",
      var.k3s_masters.backup_to_s3.bucket_region != "",
      var.k3s_masters.backup_to_s3.bucket_folder != "",
    ])
  }

  validation {
    error_message = "if enabled, all mandatory Cloudflare bucket details are specified"
    condition     = var.k3s_masters.cloudflare == null || (var.k3s_masters.cloudflare.enabled == true && alltrue([
      var.k3s_masters.cloudflare.api_token != "",
      var.k3s_masters.cloudflare.zone_id != "",
      var.k3s_masters.cloudflare.domain != "",
    ]))
  }
}

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

  #  validation {
  #    error_message = "a nodepool can be either a cpu_node or a gpu_node, only one of them can be set at once"
  #    condition     = [
  #      for name, config in var.spot_nodepools :
  #      ((config.cpu_node == null && config.gpu_node != null) || (config.cpu_node != null && config.gpu_node == null))
  #    ]
  #    #    condition     = alltrue([
  #    #      var.node_props.nvidia_gpu == null || (var.node_props.nvidia_gpu.enabled && length(var.node_props.nvidia_gpu.instance_types) > 0),
  #    #      (var.node_props.nvidia_gpu == null || !var.node_props.nvidia_gpu.enabled) && var.node_props.vcpu != null && var.node_props.memory_per_vcpu != null,
  #    #    ])
  #  }
}

variable "kloudlite_params" {
  type = object({
    release            = string
    install_crds       = bool
    install_csi_driver = bool
    install_operators  = bool

    install_agent = bool
    agent_vars    = optional(object({
      account_name             = string
      cluster_name             = string
      cluster_token            = string
      message_office_grpc_addr = string
    }))
  })

  validation {
    error_message = "description"
    condition     = var.kloudlite_params.install_agent == false || (var.kloudlite_params.agent_vars != null)
  }
}

variable "enable_nvidia_gpu_support" {
  description = "enable nvidia gpu support"
  type        = bool
}