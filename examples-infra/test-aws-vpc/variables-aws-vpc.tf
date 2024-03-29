/*
DO NOT EDIT THIS FILE DIRECTLY. IT WILL BE OVERWRITTEN.
If you need to change any variable, please edit the corresponding variables in the ../../terraform/modules/aws/vpc/variables.tf file.
If you want to create new variables, please create them in other files
*/

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "vpc CIDR"
  type        = string
}

variable "public_subnets" {
  description = "list of public subnets"
  type        = list(object({
    availability_zone = string
    cidr              = string
  }))
}

variable "tags" {
  description = "tags to be attached to resource"
  type        = map(string)
}

