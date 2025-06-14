variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  default     = ""
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = ""
}

variable "aws_assume_role" {
  type = object({
    enabled     = bool
    role_arn    = string
    external_id = optional(string, null)
  })
  default = null
}

