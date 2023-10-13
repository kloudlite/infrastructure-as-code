locals {
  primary_master_node_name = one([
    for node_name, node_cfg in var.k3s_masters.nodes : node_name
    if node_cfg.role == "primary-master"
  ])
}

resource "null_resource" "variable_validations" {
  lifecycle {
    precondition {
      error_message = "k3s_masters.nodes can/must have only one node with role primary-master"
      condition     = local.primary_master_node_name != null
    }
  }
}

module "constants" {
  source = "../../terraform/modules/common/constants"
}

module "ssh-rsa-key" {
  source     = "../../terraform/modules/common/ssh-rsa-key"
  depends_on = [null_resource.variable_validations]
}

resource "random_id" "id" {
  byte_length = 4
  depends_on  = [null_resource.variable_validations]
}

resource "aws_key_pair" "k3s_nodes_ssh_key" {
  key_name   = "${var.tracker_id}-${random_id.id.hex}-ssh-key"
  public_key = module.ssh-rsa-key.public_key
  depends_on = [null_resource.variable_validations]
}

module "aws-security-groups" {
  source                                = "../../terraform/modules/aws/security-groups"
  depends_on                            = [null_resource.variable_validations]
  allow_incoming_http_traffic_on_master = true
  allow_metrics_server_on_master        = true
  expose_k8s_node_ports_on_master       = true

  allow_incoming_http_traffic_on_agent    = false
  allow_metrics_server_on_agent           = true
  allow_outgoing_to_all_internet_on_agent = true
  expose_k8s_node_ports_on_agent          = false
  tracker_id                              = var.tracker_id
}

module "k3s-masters-nodepool" {
  source             = "../../terraform/bundles/aws-ec2-nodepool"
  depends_on         = [null_resource.variable_validations]
  instance_type      = var.k3s_masters.instance_type
  nodes              = {for name, cfg in var.k3s_masters.nodes : name => { last_recreated_at : cfg.last_recreated_at }}
  nvidia_gpu_enabled = var.k3s_masters.nvidia_gpu_enabled
  root_volume_size   = var.k3s_masters.root_volume_size
  root_volume_type   = var.k3s_masters.root_volume_type
  security_groups    = module.aws-security-groups.sg_for_k3s_masters_names
  ssh_key_name       = aws_key_pair.k3s_nodes_ssh_key.key_name
  tracker_id         = "${var.tracker_id}-masters"
  ami                = var.k3s_masters.ami
}


module "k3s-templates" {
  source = "../../terraform/modules/k3s/k3s-templates"
}

module "aws-ec2-nodepool" {
  source               = "../../terraform/bundles/aws-ec2-nodepool"
  depends_on           = [null_resource.variable_validations]
  for_each             = {for np_name, np_config in var.ec2_nodepools : np_name => np_config}
  tracker_id           = "${var.tracker_id}-${each.key}"
  ami                  = each.value.ami
  availability_zone    = each.value.availability_zone
  iam_instance_profile = each.value.iam_instance_profile
  instance_type        = each.value.instance_type
  nvidia_gpu_enabled   = each.value.nvidia_gpu_enabled
  root_volume_size     = each.value.root_volume_size
  root_volume_type     = each.value.root_volume_type
  security_groups      = module.aws-security-groups.sg_for_k3s_masters_names
  ssh_key_name         = aws_key_pair.k3s_nodes_ssh_key.key_name
  nodes                = {
    for name, cfg in each.value.nodes : name => {
      user_data = template(module.k3s-templates.k3s-agent-template, {
        tf_k3s_masters_dns_host = var.k3s_masters.public_dns_host
        tf_k3s_token            = module.k3s-primary-master.k3s_token
        tf_node_labels          = jsonencode(merge(local.common_node_labels, {
          (module.constants.node_labels.provider_az)   = each.value.availability_zone,
          (module.constants.node_labels.node_has_role) = "agent"
          (module.constants.node_labels.node_is_spot)  = "true"
        }))
        tf_node_name = "${var.tracker_id}-${name}"
      })
      last_recreated_at = cfg.last_recreated_at
    }
  }
}

module "aws-spot-nodepool" {
  source                       = "../../terraform/bundles/aws-spot-nodepool"
  depends_on                   = [null_resource.variable_validations]
  for_each                     = {for np_name, np_config in var.spot_nodepools : np_name => np_config}
  tracker_id                   = "${var.tracker_id}-${each.key}"
  ami                          = each.value.ami
  availability_zone            = each.value.availability_zone
  root_volume_size             = each.value.root_volume_size
  root_volume_type             = each.value.root_volume_type
  security_groups              = module.aws-security-groups.sg_for_k3s_masters_ids
  spot_fleet_tagging_role_name = each.value.spot_fleet_tagging_role_name
  ssh_key_name                 = aws_key_pair.k3s_nodes_ssh_key.key_name
  cpu_node                     = each.value.cpu_node
  gpu_node                     = each.value.gpu_node
  nodes                        = {
    for name, cfg in each.value.nodes : name => {
      user_data = templatefile(module.k3s-templates.k3s-agent-template, {
        tf_k3s_masters_dns_host = var.k3s_masters.public_dns_host
        tf_k3s_token            = module.k3s-primary-master.k3s_token
        tf_node_labels          = jsonencode(merge(local.common_node_labels, {
          (module.constants.node_labels.provider_az)   = each.value.availability_zone,
          (module.constants.node_labels.node_has_role) = "agent"
          (module.constants.node_labels.node_is_spot)  = "true"
        }))
        tf_node_name = "${var.tracker_id}-${name}"
      })
      last_recreated_at = cfg.last_recreated_at
    }
  }
}

locals {
  common_node_labels = {
    (module.constants.node_labels.provider_name) : "aws",
    (module.constants.node_labels.provider_region) : var.aws_region,
  }

  backup_crontab_schedule = {
    # for idx, name in local.master_names : name => "*/1 * * * *"
    for idx, name in var.k3s_masters.nodes : name =>
    "* ${2 * (tonumber(idx) + 1)}/${2 * length(var.k3s_masters.nodes)} * * *"
  }
}

module "k3s-primary-master" {
  source     = "../../terraform/modules/k3s/k3s-primary-master"
  depends_on = [module.k3s-masters-nodepool]

  node_name  = local.primary_master_node_name
  #  public_dns_hostname = var.k3s_server_dns_hostname
  public_ip  = module.k3s-masters-nodepool.public_ips[local.primary_master_node_name]
  ssh_params = {
    user        = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }

  node_labels = merge(local.common_node_labels, {
    (module.constants.node_labels.provider_az) : var.k3s_masters.nodes[local.primary_master_node_name].availability_zone,
    (module.constants.node_labels.node_has_role) : var.k3s_masters.nodes[local.primary_master_node_name].role,
  })

  node_taints = var.k3s_masters.taint_master_nodes ? module.constants.master_node_taints : {}

  k3s_master_nodes_public_ips = [module.k3s-masters-nodepool.public_ips[local.primary_master_node_name]]
  backup_to_s3                = {
    enabled = var.k3s_masters.backup_to_s3.enabled

    aws_access_key = var.aws_access_key
    aws_secret_key = var.aws_secret_key

    bucket_name   = var.k3s_masters.backup_to_s3.bucket_name
    bucket_region = var.k3s_masters.backup_to_s3.bucket_region
    bucket_folder = var.k3s_masters.backup_to_s3.bucket_folder

    cron_schedule = local.backup_crontab_schedule[local.primary_master_node_name]
  }

  restore_from_latest_s3_snapshot = var.k3s_masters.restore_from_latest_snapshot

  public_dns_host = var.k3s_masters.public_dns_host
}

module "k3s-secondary-master" {
  source   = "../../terraform/modules/k3s/k3s-secondary-master"
  for_each = {
    for node_name, node_cfg in var.k3s_masters.nodes : node_name => node_cfg
    if node_cfg.role == "secondary-master"
  }
  k3s_token                = module.k3s-primary-master.k3s_token
  primary_master_public_ip = module.k3s-primary-master.public_ip
  public_dns_hostname      = var.k3s_masters.public_dns_host

  depends_on = [module.k3s-primary-master]

  node_name   = each.key
  node_taints = var.k3s_masters.taint_master_nodes ? module.constants.master_node_taints : {}
  ssh_params  = {
    public_ip   = module.k3s-masters-nodepool.public_ips[each.key]
    user        = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
  node_labels = merge(
    local.common_node_labels,
    {
      (module.constants.node_labels.provider_az) : var.k3s_masters.nodes[local.primary_master_node_name].availability_zone,
      (module.constants.node_labels.node_has_role) : var.k3s_masters.nodes[local.primary_master_node_name].role,
    }
  )

  backup_to_s3 = {
    enabled = var.k3s_masters.backup_to_s3.enabled

    aws_access_key = var.aws_access_key
    aws_secret_key = var.aws_secret_key

    bucket_name   = var.k3s_masters.backup_to_s3.bucket_name
    bucket_region = var.k3s_masters.backup_to_s3.bucket_region
    bucket_folder = var.k3s_masters.backup_to_s3.bucket_folder

    cron_schedule = local.backup_crontab_schedule[local.primary_master_node_name]
  }

  restore_from_latest_s3_snapshot = var.k3s_masters.restore_from_latest_snapshot
}

module "cloudflare-dns" {
  count  = var.k3s_masters.cloudflare.enabled ? 1 : 0
  source = "../../terraform/modules/cloudflare/dns"

  cloudflare_api_token = var.k3s_masters.cloudflare.api_token
  cloudflare_domain    = var.k3s_masters.cloudflare.domain
  cloudflare_zone_id   = var.k3s_masters.cloudflare.zone_id

  public_ips         = [for name, ip in module.k3s-masters-nodepool.public_ips : ip]
  set_wildcard_cname = true
}

module "kloudlite-crds" {
  count             = var.kloudlite_params.install_crds ? 1 : 0
  source            = "../../terraform/modules/kloudlite/crds"
  kloudlite_release = var.kloudlite_params.release
  depends_on        = [module.k3s-primary-master]
  ssh_params        = {
    public_ip   = module.k3s-primary-master.public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "helm-aws-ebs-csi" {
  count           = var.kloudlite_params.install_csi_driver ? 1 : 0
  source          = "../../terraform/modules/helm-charts/helm-aws-ebs-csi"
  depends_on      = [module.kloudlite-crds]
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
  node_selector = {
    (module.constants.node_labels.node_has_role) : "agent"
  }
  ssh_params = {
    public_ip   = module.k3s-primary-master.public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "nvidia-container-runtime" {
  count      = var.enable_nvidia_gpu_support ? 1 : 0
  source     = "../../terraform/modules/nvidia-container-runtime"
  depends_on = [module.kloudlite-crds]
  ssh_params = {
    public_ip   = module.k3s-primary-master.public_ip
    user        = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
  gpu_nodes_selector = {
    (module.constants.node_labels.node_has_gpu) : "true"
  }
}

module "kloudlite-operators" {
  count             = var.kloudlite_params.install_operators ? 1 : 0
  source            = "../../terraform/modules/helm-charts/kloudlite-operators"
  depends_on        = [module.kloudlite-crds]
  kloudlite_release = var.kloudlite_params.release
  node_selector     = {}
  ssh_params        = {
    public_ip   = module.k3s-primary-master.public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "kloudlite-agent" {
  count                              = var.kloudlite_params.install_agent ? 1 : 0
  source                             = "../../terraform/modules/kloudlite/helm-agent"
  kloudlite_account_name             = var.kloudlite_params.agent_vars.account_name
  kloudlite_cluster_name             = var.kloudlite_params.agent_vars.cluster_name
  kloudlite_cluster_token            = var.kloudlite_params.agent_vars.cluster_token
  kloudlite_dns_host                 = var.k3s_masters.public_dns_host
  kloudlite_message_office_grpc_addr = var.kloudlite_params.agent_vars.message_office_grpc_addr
  kloudlite_release                  = var.kloudlite_params.release
  ssh_params                         = {
    public_ip   = module.k3s-primary-master.public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}
