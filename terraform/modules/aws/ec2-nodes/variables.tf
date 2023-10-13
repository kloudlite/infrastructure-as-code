#variable "save_ssh_key" {
#  type = object({
#    enabled = string
#    path    = string
#  })
#  default = null
#}

variable "ssh_key_name" {
  description = "ssh_key_name to be used when creating instances. It is the output of aws_key_pair.<var-name>.key_name"
  type        = string
}

variable "nodes_config" {
  type = map(object({
    ami                  = string
    instance_type        = string
    az                   = optional(string)
    root_volume_size     = number
    root_volume_type     = string // standard, gp2, io1, gp3 etc
    with_elastic_ip      = bool
    security_groups      = list(string)
    iam_instance_profile = optional(string)
    recreate             = optional(bool)
  }))
}