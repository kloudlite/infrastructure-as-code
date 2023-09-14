terraform {
  required_version = ">= 1.2.0"

  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "2.6.0"
    }
  }
}

provider "ssh" {
  debug_log = "/tmp/terraform-iac.ssh.log"
}
