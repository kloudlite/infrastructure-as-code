variable "ami" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "save_ssh_key" {
  type    = bool
  default = false
}

variable "nodes_config" {
  type = map(object({
    instance_type     = string
    az = string
    root_volume_size  = number
    root_volume_type  = string // standard, gp2, io1, gp3 etc
    with_elastic_ip = bool
  }))
}