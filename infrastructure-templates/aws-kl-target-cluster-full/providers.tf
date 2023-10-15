terraform {
  required_version = ">= 1.2.0"
  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "2.6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.13.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "ssh" {
  debug_log = "/tmp/example-cluster-ssh-debug.log"
}

provider "cloudflare" {
  api_token = (var.k3s_masters.cloudflare != null && var.k3s_masters.cloudflare.enabled) ? var.k3s_masters.cloudflare.api_token : null
}
