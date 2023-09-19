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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

#resource "template_file" "kubeconfig" {
#  template = base64encode(module.k3s-primary-master.kubeconfig_with_public_ip)
#}

data "template_file" "kubeconfig" {
  template = base64encode(module.k3s-primary-master.kubeconfig_with_public_ip)
}

#resource "local_file" "kubeconfig" {
#  #  content = base64decode(module.k3s-primary-master.kubeconfig_with_public_ip)
#  content  = base64decode(module.k3s-primary-master.kubeconfig_with_public_ip)
#  filename = "/tmp/kubeconfig"
#}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "helm" {
  kubernetes {
    #    config_path = local_file.kubeconfig.filename
    config_path = data.template_file.kubeconfig.filename
  }
}

provider "ssh" {
  debug_log = "/tmp/kloudlite-iac-ssh.log"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "kubectl" {
  #  config_path = local_file.kubeconfig.filename
  config_path = data.template_file.kubeconfig.filename
}