variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

variable "aws_region" { type = string }
variable "aws_ami" {
  description = "kloudlite aws ami"
  type        = string
}

variable "aws_nvidia_gpu_ami" {
  description = "kloudlite aws nvidia gpu ami"
  type        = string
}

variable "aws_iam_instance_profile_role" {
  description = "aws iam instance profile role"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" { type = string }

variable "cloudflare_domain" { type = string }
variable "cloudflare_zone_id" { type = string }

variable "ec2_nodes_config" {
  description = "ec2 nodes configuration"
  type        = map(object({
    az                 = string
    role               = string
    instance_type      = optional(string, "c6a.large")
    root_volume_size   = optional(number, 50)
    root_volume_type   = optional(string, "gp3")
    with_elastic_ip    = optional(bool, false)
    is_nvidia_gpu_node = optional(bool)
  }))

  validation {
    condition = alltrue([
      for k, v in var.ec2_nodes_config :contains(["primary-master", "secondary-master", "agent"], v.role)
    ])
    error_message = "Invalid node role, must be one of primary, secondary or agent"
  }
}

variable "spot_settings" {
  description = "spot nodes settings"
  type        = object({
    enabled                      = bool
    spot_fleet_tagging_role_name = optional(string)
  })

  validation {
    condition     = !var.spot_settings.enabled || var.spot_settings.spot_fleet_tagging_role_name != ""
    error_message = "when spot_settings is enabled, spot_fleet_tagging_role_name is required"
  }
}

variable "spot_nodes_config" {
  description = "spot nodes configuration"
  type        = map(object({
    vcpu = optional(object({
      min = number
      max = number
    }))
    memory_per_vcpu = optional(object({
      min = number
      max = number
    }))
    root_volume_size = optional(number, 50)
    root_volume_type = optional(string, "gp3")
    allow_public_ip  = optional(bool, false)
    nvidia_gpu       = optional(object({
      enabled        = bool
      ami            = optional(string)
      instance_types = list(string)
    }))
  }))
}

variable "disable_ssh" {
  description = "disable ssh access to the nodes"
  type        = bool
  default     = true
}

variable "taint_master_nodes" {
  description = "taint master nodes, so that nothing is deployed on it by default"
  type        = bool
}

variable "kloudlite_release" {
  description = "kloudlite release version to install"
  type        = string
}

variable "kloudlite_agent_vars" {
  description = "kloudlite agent vars"
  type        = object({
    install                  = bool
    account_name             = optional(string)
    cluster_name             = optional(string)
    cluster_token            = optional(string)
    dns_host                 = optional(string)
    message_office_grpc_addr = optional(string)
  })

  validation {
    error_message = "when kloudlite_agent_vars.install is true, all the following variables must be set: account_name, cluster_name, cluster_token, dns_host, message_office_grpc_addr"
    condition     = var.kloudlite_agent_vars.install == false || (
    var.kloudlite_agent_vars.account_name != "" &&
    var.kloudlite_agent_vars.cluster_name != "" &&
    var.kloudlite_agent_vars.cluster_token != "" &&
    var.kloudlite_agent_vars.dns_host != "" &&
    var.kloudlite_agent_vars.message_office_grpc_addr != ""
    )
  }
}

variable "enable_nvidia_gpu_support" {
  description = "enable nvidia gpu support"
  type        = bool
}
