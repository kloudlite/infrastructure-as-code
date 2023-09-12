locals {
  #  default_master_nodes_config = {
  #    instance_type    = "c6a.large"
  #    root_volume_size = 40
  #    root_volume_type = "gp3"
  #  }
  #
  #  default_worker_nodes_config = {
  #    instance_type    = "c6a.large"
  #    root_volume_size = 50
  #    root_volume_type = "gp3"
  #  }

  k3s_node_labels = {
    "kloudlite.io/cloud-provider.name" : "aws",
    "kloudlite.io/cloud-provider.region" : var.aws_region,
  }

  k3s_node_label_az = "kloudlite.io/cloud-provider.az"

  #  nodes = {
  #    "master-1" : merge({ az = "ap-south-1a", role = "primary" }, local.default_master_nodes_config),
  #    "master-2" : merge({ az = "ap-south-1b", role = "secondary" }, local.default_master_nodes_config),
  #    "master-3" : merge({ az = "ap-south-1c", role = "secondary" }, local.default_master_nodes_config),
  #
  #    "worker-1" : merge({ az = "ap-south-1b", role = "agent" }, local.default_worker_nodes_config),
  #  }

  primary_master_nodes = {
    for node_name, node_cfg in var.nodes_config : node_name => node_cfg if node_cfg.role == "primary-master"
  }
  secondary_master_nodes = {
    for node_name, node_cfg in var.nodes_config : node_name => node_cfg if node_cfg.role == "secondary-master"
  }
  agent_nodes = {for node_name, node_cfg in var.nodes_config : node_name => node_cfg if node_cfg.role == "agent"}
}

check "single_master" {
  assert {
    condition     = length(local.primary_master_nodes) == 1
    error_message = "only one primary master node is allowed"
  }
}

locals {
  primary_master_node_name = keys(local.primary_master_nodes)[0]
  primary_master_node      = local.primary_master_nodes[local.primary_master_node_name]
}

module "ec2-nodes" {
  source       = "../modules/ec2-nodes"
  save_ssh_key = true

  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  ami        = var.aws_ami
  aws_region = var.aws_region

  nodes_config = var.nodes_config
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
  node_labels = merge({
    "kloudlite.io/cloud-provider.az" : local.primary_master_node.az
  }, local.k3s_node_labels)
  use_cloudflare_nameserver = true
}

module "k3s-secondary-master" {
  source = "../modules/k3s-secondary-master"

  k3s_token                = module.k3s-primary-master.k3s_token
  primary_master_public_ip = module.k3s-primary-master.public_ip
  public_domain            = var.cloudflare_domain

  depends_on = [module.k3s-primary-master]

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
      depends_on  = [module.k3s-primary-master]
      node_labels = merge({ "kloudlite.io/cloud-provider.az" : node_cfg.az }, local.k3s_node_labels)
    }
  }

  use_cloudflare_nameserver = true

  #  k3s_server_host = module.k3s-primary-master.public_ip
  #  k3s_server_host = aws_eip.k3s_masters_elastic_ips[local.primary_master_node_name].public_ip
  k3s_server_host = var.cloudflare_domain
  k3s_token       = module.k3s-primary-master.k3s_token
}

output "ec2_instances" {
  value = module.ec2-nodes.ec2_instances
}

output "kubeconfig" {
  value = module.k3s-primary-master.kubeconfig_with_public_host
}

module "cloudflare-dns" {
  source = "../modules/cloudflare-dns"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_domain    = var.cloudflare_domain
  cloudflare_zone_id   = var.cloudflare_zone_id

  public_ips = [
    for node_name, v in merge(local.primary_master_nodes, local.secondary_master_nodes) :
    module.ec2-nodes.ec2_instances[node_name].public_ip
  ]
}

resource "time_sleep" "sleep_before_applying_helm" {
  create_duration = "1m"
  depends_on = [module.k3s-primary-master]
}

module "helm-aws-ebs-csi" {
  providers = {
    helm = helm
  }
  source     = "../modules/helm-aws-ebs-csi"
  kubeconfig = module.k3s-primary-master.kubeconfig_with_public_ip
  depends_on = [time_sleep.sleep_before_applying_helm]
  storage_classes = {
    "sc-xfs" : {
      volume_type = "gp3"
      fs_type     = "xfs"
    },
    "sc-ext4" : {
      volume_type = "gp3"
      fs_type     = "ext4"
    },
  }
}
