packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "builder" {
  for_each      = {}
  ami_name      = var.ami_name
  instance_type = "t2.micro"
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-xenial-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.builder"]

  provisioner "file" {
    source      = "../tf-packer.pub"
    destination = "/tmp/tf-packer.pub"
  }
  provisioner "shell" {
    script = "../scripts/setup.sh"
  }
}
