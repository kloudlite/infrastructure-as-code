variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

variable "aws_region" { default = "ap-south-1" }
variable "aws_ami" { default = "ami-0f78219c8292792d9" }

variable "cloudflare_api_token" { type = string }

variable "cloudflare_domain" { default = "dev2.kloudlite.io" }
variable "cloudflare_zone_id" { default = "67f645257a633bd1eb1091facfafba04" }

locals {
  default_master_nodes_config = {
    instance_type    = "c6a.large"
    root_volume_size = 40
    root_volume_type = "gp3"
  }

  default_worker_nodes_config = {
    instance_type    = "c6a.large"
    root_volume_size = 50
    root_volume_type = "gp3"
  }

  k3s_node_labels = {
    "kloudlite.io/cloud-provider.name" : "aws",
    "kloudlite.io/cloud-provider.region" : var.aws_region,
  }

  k3s_node_label_az = "kloudlite.io/cloud-provider.az"

  nodes = {
    "master-1" : merge({ az = "ap-south-1a", role = "primary" }, local.default_master_nodes_config),
    "master-2" : merge({ az = "ap-south-1b", role = "secondary" }, local.default_master_nodes_config),
    "master-3" : merge({ az = "ap-south-1c", role = "secondary" }, local.default_master_nodes_config),

    "worker-1" : merge({ az = "ap-south-1b", role = "agent" }, local.default_worker_nodes_config),
  }

  primary_master_node_name = "master-1"
  primary_master_node      = local.nodes[local.primary_master_node_name]
  secondary_master_nodes   = { for node_name, node_cfg in local.nodes : node_name => node_cfg if node_cfg.role == "secondary"}
  agent_nodes              = { for node_name, node_cfg in local.nodes : node_name => node_cfg if node_cfg.role == "agent"}
}

module "ec2-nodes" {
  source       = "../modules/ec2-nodes"
  save_ssh_key = true

  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  ami        = var.aws_ami
  aws_region = var.aws_region

  nodes_config = local.nodes
}

module "k3s-primary-master" {
  source = "../modules/k3s-primary-master"

  node_name     = local.primary_master_node_name
  public_domain = var.cloudflare_domain
  public_ip     = module.ec2-nodes.ec2_instances[local.primary_master_node_name].public_ip
  ssh_params    = {
    user        = "ubuntu",
    private_key = module.ec2-nodes.ssh_private_key
  }
  node_labels = merge({ "kloudlite.io/cloud-provider.az" : local.primary_master_node.az }, local.k3s_node_labels)
}

module "k3s-secondary-master" {
  source = "../modules/k3s-secondary-master"

  k3s_token                = module.k3s-primary-master.k3s_token
  primary_master_public_ip = module.k3s-primary-master.public_ip
  public_domain            = var.cloudflare_domain

  secondary_masters = {
    for node_name, node_cfg in local.secondary_master_nodes : node_name => {
      public_ip  = module.ec2-nodes.ec2_instances[node_name].public_ip
      ssh_params = {
        user        = "ubuntu"
        private_key = module.ec2-nodes.ssh_private_key
      }
      node_labels = merge({ "kloudlite.io/cloud-provider.az" : node_cfg.az }, local.k3s_node_labels)
    }
  }

  #  secondary_masters2 = {
  #    "master-2" : {
  #      public_ip  = module.ec2-nodes.ec2_instances["master-2"].public_ip
  #      ssh_params = {
  #        user        = "ubuntu"
  #        private_key = module.ec2-nodes.ssh_private_key
  #      }
  #      node_labels = concat(local.k3s_node_labels,
  #        [format(local.k3s_node_label_az, module.ec2-nodes.ec2_instances["master-2"].az)]
  #      )
  #    },
  #
  #    "master-3" : {
  #      public_ip  = module.ec2-nodes.ec2_instances["master-3"].public_ip
  #      ssh_params = {
  #        user        = "ubuntu"
  #        private_key = module.ec2-nodes.ssh_private_key
  #      }
  #      node_labels = concat(local.k3s_node_labels,
  #        [format(local.k3s_node_label_az, module.ec2-nodes.ec2_instances["master-2"].az)]
  #      )
  #    }
  #  }
}

module "k3s-agents" {
  source = "../modules/k3s-agents"

  agent_nodes = {
    for node_name, node_cfg in local.agent_nodes : node_name => {
      public_ip  = module.ec2-nodes.ec2_instances_ips[node_name]
      ssh_params = {
        user        = "ubuntu"
        private_key = module.ec2-nodes.ssh_private_key
      }
      node_labels = merge({ "kloudlite.io/cloud-provider.az" : node_cfg.az}, local.k3s_node_labels)
    }
  }

#  agent_nodes = {
#    for node_name, node_cfg in local.nodes : node_name => {
#      public_ip  = module.ec2-nodes.ec2_instances_ips[node_name]
#      ssh_params = {
#        user        = "ubuntu"
#        private_key = module.ec2-nodes.ssh_private_key
#      }
#      node_labels = merge({
#        "kloudlite.io/cloud-provider.az" : module.ec2-nodes.ec2_instances["master-1"].az
#      }, local.k3s_node_labels)
#    } if node_cfg.role == "agent"
#  }

  #  agent_nodes2 = {
  #    "worker-1" : {
  #      public_ip  = module.ec2-nodes.ec2_instances_ips["worker-1"]
  #      ssh_params = {
  #        user        = "ubuntu"
  #        private_key = module.ec2-nodes.ssh_private_key
  #      }
  #      node_labels = concat(local.k3s_node_labels,
  #        [format(local.k3s_node_label_az, module.ec2-nodes.ec2_instances_azs["worker-1"])]
  #      )
  #    }
  #  }

  k3s_server_host = module.k3s-primary-master.public_ip
  k3s_token       = module.k3s-primary-master.k3s_token
}

output "ec2_instances" {
  value = module.ec2-nodes.ec2_instances
}

output "kubeconfig" {
  value = module.k3s-primary-master.kubeconfig
}

module "cloudflare-dns" {
  source = "../modules/cloudflare-dns"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_domain    = var.cloudflare_domain
  cloudflare_zone_id   = var.cloudflare_zone_id

  public_ips = concat(
    [module.ec2-nodes.ec2_instances[local.primary_master_node_name].public_ip],
    [for node_name, node_cfg in local.secondary_master_nodes : module.ec2-nodes.ec2_instances[node_name].public_ip],
  )
}

