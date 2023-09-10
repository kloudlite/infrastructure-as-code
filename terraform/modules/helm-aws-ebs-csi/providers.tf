terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

resource "local_file" "kubeconfig" {
  content = base64decode(var.kubeconfig)
  filename = "/tmp/kubeconfig"
}

provider "helm" {
  kubernetes {
    config_path = local_file.kubeconfig
  }
}