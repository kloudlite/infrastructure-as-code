variable "k3s_server_host" {
  description = "The domain name or ip that points to k3s master nodes"
  type        = string
}

variable "k3s_token" {
  description = "k3s token used to join agent nodes to the k3s cluster"
  type        = string
}

variable "aws_ami" {
  description = "The ami used to create the spot nodes, that will be added as agents to a k3s cluster"
  type        = string
}

variable "spot_nodes" {
  description = "map of spot nodes to be added to the k3s cluster (as agents)"
  type        = map(object({
    instance_type        = string
    az                   = string
    #    max_price_per_hour = optional(number)
    node_labels          = map(string)
    root_volume_type     = optional(string, "gp3")
    root_volume_size     = optional(number, 40)
    security_groups      = list(string)
    iam_instance_profile = optional(string)
  }))
}

variable "disable_ssh" {
  description = "Disable ssh connection to the k3s agent nodes"
  type        = bool
  default     = true
}

variable "save_ssh_key" {
  type = object({
    enabled = string
    path    = optional(string)
  })
  default = {
    enabled = false
  }
}
