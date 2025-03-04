variable "name_prefix" {
  type        = string
  description = "name prefixes to use for resources"
}

variable "provision_mode" {
  type = string
}

variable "network" {
  description = "GCP Network"
  type        = string
}

variable "nodes" {
  type = map(object({
    availability_zone = string
    k3s_role          = string
    kloudlite_release = string
    bootvolume_size   = number
    bootvolume_type   = string
    node_labels       = optional(map(string))
  }))
  description = "map of node name to its availability_zone and k3s role"
}

variable "machine_type" {
  description = "machine_type"
  type        = string
}

variable "k3s_service_cidr" {
  type        = string
  description = "k3s service CIDR to use for this cluster, as specified in https://docs.k3s.io/networking/basic-network-options?_highlight=cidr#dual-stack-ipv4--ipv6-networking"
  default     = ""
}

variable "cluster_internal_dns_host" {
  type    = string
  default = "cluster.local"
}

variable "public_dns_host" {
  type        = string
  description = "public DNS Hostname to be attached to created nodes, like abcd.example.com"
}

variable "cloudflare" {
  description = "cloudflare related parameters"
  type = object({
    enabled   = bool
    api_token = optional(string)
    zone_id   = optional(string)
    domain    = optional(string)
  })

  validation {
    error_message = "if enabled, all mandatory Cloudflare bucket details are specified"
    condition = var.cloudflare == null || (var.cloudflare.enabled == true && alltrue([
      var.cloudflare.api_token != "",
      var.cloudflare.zone_id != "",
      var.cloudflare.domain != "",
    ]))
  }
}

variable "kloudlite_params" {
  description = "kloudlite related parameters"
  type = object({
    release            = string
    install_crds       = optional(bool, true)
    install_csi_driver = optional(bool, false)
    install_operators  = optional(bool, false)

    install_agent       = optional(bool, false)
    install_autoscalers = optional(bool, true)
    agent_vars = optional(object({
      account_name             = string
      cluster_name             = string
      cluster_token            = string
      message_office_grpc_addr = string
    }))
  })

  validation {
    error_message = "description"
    condition     = var.kloudlite_params.install_agent == false || var.kloudlite_params.agent_vars != null
  }
}

variable "save_ssh_key_to_path" {
  description = "save ssh key to this path"
  type        = string
  default     = ""
}

variable "save_kubeconfig_to_path" {
  description = "save kubeconfig to this path"
  type        = string
  default     = ""
}

variable "labels" {
  type        = map(string)
  description = "map of Key => Value to be tagged along created resources"
  default     = {}
}

variable "service_account" {
  type = object({
    enabled = bool
    email   = optional(string)
    scopes  = optional(list(string))
  })
}

variable "k3s_download_url" {
  type        = string
  description = "k3s download URL"
}

variable "kloudlite_runner_download_url" {
  type        = string
  description = "kloudlite runner download URL"
}

variable "machine_state" {
  type = string
}

variable "gcp_region" {
  type        = string
  description = "gcp region"
}
