variable "aws_region" {
  type    = string
  default = ""
}

variable "aws_access_key" {
  type    = string
  default = ""
}

variable "aws_secret_key" {
  type    = string
  default = ""
}

variable "master_nodes_config" {
  type = object(
    {
      name               = string
      count              = number
      instance_type      = string
      ami                = optional(string)
      availability_zones = list(string)
    }
  )
}

variable "worker_nodes_config" {
  type = object(
    {
      name               = string
      count              = number
      instance_type      = string
      ami                = optional(string)
      availability_zones = list(string)
    }
  )
}

variable "storage_volumes_config" {
  type = map(map(object({
    size = optional(number, 100)
    type = optional(string, "gp2")
    iops = optional(number, 300)
  })))
}

variable "storage_nodes_config" {
  type = object(
    {
      name               = string
      count              = number
      instance_type      = string
      ami                = optional(string)
      availability_zones = list(string)
    }
  )
}

variable "domain" {
  type    = string
  default = ""
}

variable "disable_ssh" {
  type    = bool
  default = true
}

variable "save_ssh_key_as" {
  type    = string
  default = ""
}

variable "storage_nodes_count" {
  type    = number
  default = 3
}
