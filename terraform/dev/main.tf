variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

variable "cloudflare_api_token" { type = string }

variable "cloudflare_domain" { default = "dev2.kloudlite.io" }
variable "cloudflare_zone_id" { default = "67f645257a633bd1eb1091facfafba04" }

# variable "aws_ami" { default = "ami-05d2a63c2d53d7292" }
variable "aws_ami" { default = "ami-0f78219c8292792d9" }
variable "aws_instance_type" { default = "c6a.large" }
variable "aws_region_availability_zones" { default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"] }

module "k3s-primary-master" {
  source = "../modules/k3s-primary-master"

  node_name     = ""
  public_domain = ""
  public_ip     = ""
  ssh_params    = {}
}

module "k3s-HA-on-ec2" {
  source = "../modules/k3s-HA-on-ec2"

  master_nodes_config = {
    name               = "kloudlite-dev-master"
    count              = 1
    instance_type      = var.aws_instance_type
    ami                = var.aws_ami
    availability_zones = var.aws_region_availability_zones
  }

  worker_nodes_config = {
    name               = "kloudlite-dev-worker",
    count              = 1,
    instance_type      = var.aws_instance_type
    ami                = var.aws_ami
    availability_zones = [var.aws_region_availability_zones[0]]
  }

  storage_volumes_config = {
    "ap-south-1a/volume-1" = {
      mount_path = "/mnt/volume-1"
    },
    "ap-south-1a/volume-2" = {
      mount_path = "/mnt/volume-2"
    },

    "ap-south-1b/volume-1" = {
      mount_path = "/mnt/volume-1"
    },
    "ap-south-1b/volume-2" = {
      mount_path = "/mnt/volume-2"
    },

    "ap-south-1c/volume-1" = {
      mount_path = "/mnt/volume-1"
    },
    "ap-south-1c/volume-2" = {
      mount_path = "/mnt/volume-2"
    },
  }

  availitilityZone = {
    name =  ""
    masterNodes = {
      "adadf": {
      },

      "adadf": {
      },

      "adadf": {
      },
    },
    workerNodes = {},
    volumes = {},
    storageNodes= [
      {
        name = ""
        instance_type = ""
        ami = ""
        availability_zone = ""
        attached_volumes = ["volume-name-1", "volume-name-2"]
      }
    ]
  }

  storage_nodes_config = {
    "k8s-dev-storage-worker-1" = {
      instance_type      = var.aws_instance_type
      ami                = var.aws_ami
      availability_zone = var.aws_region_availability_zones[0]
      attached_volumes = [
        "ap-south-1a/volume-1",
        "ap-south-1a/volume-2",
      ]
    },
#    name               = "kloudlite-dev-storage-worker",
#    count              = 4,
#    instance_type      = var.aws_instance_type
#    ami                = var.aws_ami
#    availability_zones = [var.aws_region_availability_zones[0]]
  }

  domain = var.cloudflare_domain

  aws_region     = "ap-south-1"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  # disable_ssh = true
  disable_ssh     = false
  save_ssh_key_as = "/tmp/iac-dev.pem"
}

output "kubeconfig" {
  value = module.k3s-HA-on-ec2.kubeconfig
}

module "cloudflare-dns" {
  source = "../modules/cloudflare-dns"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_domain    = var.cloudflare_domain
  cloudflare_zone_id   = var.cloudflare_zone_id

  public_ips = module.k3s-HA-on-ec2.k8s_masters_public_ips
}

