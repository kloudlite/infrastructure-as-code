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
  source = "../../modules/common/constants"
}

module "ssh-rsa-key" {
  source     = "../../modules/common/ssh-rsa-key"
  depends_on = [null_resource.variable_validations]
}

resource "null_resource" "save_ssh_key" {
  count = length(var.save_ssh_key_to_path) > 0? 1 : 0

  provisioner "local-exec" {
    quiet   = true
    command = "echo '${module.ssh-rsa-key.private_key}' > ${var.save_ssh_key_to_path} && chmod 600 ${var.save_ssh_key_to_path}"
  }
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
  source                                = "../../modules/aws/security-groups"
  depends_on                            = [null_resource.variable_validations]
  create_group_for_k3s_masters          = true
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
  source             = "../../modules/aws/aws-ec2-nodepool"
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
  source = "../../modules/k3s/k3s-templates"
}

locals {
  common_node_labels = {
    (module.constants.node_labels.provider_name) : "aws",
    (module.constants.node_labels.provider_region) : var.aws_region,
  }

  backup_crontab_schedule = {
    # for idx, name in local.master_names : name => "*/1 * * * *"
    for idx, node_name in [for k, _node_cfg in var.k3s_masters.nodes : k] : node_name =>
    "* ${2 * (tonumber(idx) + 1)}/${2 * length(var.k3s_masters.nodes)} * * *"
  }
}

module "k3s-masters" {
  source       = "../../modules/k3s/k3s-master"
  backup_to_s3 = {
    enabled = var.k3s_masters.backup_to_s3.enabled

    aws_access_key = var.aws_access_key
    aws_secret_key = var.aws_secret_key

    bucket_name   = var.k3s_masters.backup_to_s3.bucket_name
    bucket_region = var.k3s_masters.backup_to_s3.bucket_region
    bucket_folder = var.k3s_masters.backup_to_s3.bucket_folder
  }
  cluster_internal_dns_host       = var.k3s_masters.cluster_internal_dns_host
  restore_from_latest_s3_snapshot = var.k3s_masters.restore_from_latest_snapshot
  master_nodes                    = {
    for k, v in var.k3s_masters.nodes : k => {
      role : v.role,
      public_ip : module.k3s-masters-nodepool.public_ips[k]
      node_labels : merge(local.common_node_labels, {
        (module.constants.node_labels.provider_az) : v.availability_zone,
        (module.constants.node_labels.node_has_role) : v.role,
      })
    }
  }
  public_dns_host = var.k3s_masters.public_dns_host
  ssh_params      = {
    user        = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
  node_taints       = var.k3s_masters.taint_master_nodes ? module.constants.master_node_taints : []
  extra_server_args = var.extra_server_args
}

resource "null_resource" "save_kubeconfig" {
  count = length(var.save_kubeconfig_to_path) > 0 ? 1 : 0

  depends_on = [module.k3s-masters.kubeconfig_with_public_host]

  provisioner "local-exec" {
    quiet   = true
    command = "echo '${base64decode(module.k3s-masters.kubeconfig_with_public_host)}' > ${var.save_kubeconfig_to_path} && chmod 600 ${var.save_kubeconfig_to_path}"
  }
}

module "cloudflare-dns" {
  count  = var.k3s_masters.cloudflare.enabled ? 1 : 0
  source = "../../modules/cloudflare/dns"

  depends_on = [module.k3s-masters-nodepool]

  cloudflare_api_token = var.k3s_masters.cloudflare.api_token
  cloudflare_domain    = var.k3s_masters.cloudflare.domain
  cloudflare_zone_id   = var.k3s_masters.cloudflare.zone_id

  public_ips         = [for name, ip in module.k3s-masters-nodepool.public_ips : ip]
  set_wildcard_cname = true
}

module "kloudlite-crds" {
  count             = var.kloudlite_params.install_crds ? 1 : 0
  source            = "../../modules/kloudlite/crds"
  kloudlite_release = var.kloudlite_params.release
  #  depends_on        = [module.k3s-primary-master]
  depends_on        = [module.k3s-masters.kubeconfig_with_public_host]
  ssh_params        = {
    #    public_ip   = module.k3s-primary-master.public_ip
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "helm-aws-ebs-csi" {
  count           = var.kloudlite_params.install_csi_driver ? 1 : 0
  source          = "../../modules/helm-charts/helm-aws-ebs-csi"
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
  controller_node_selector = module.constants.master_node_selector
  controller_tolerations   = module.constants.master_node_tolerations
  daemonset_node_selector  = module.constants.agent_node_selector
  ssh_params               = {
    #    public_ip   = module.k3s-primary-master.public_ip
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "nvidia-container-runtime" {
  count      = var.enable_nvidia_gpu_support ? 1 : 0
  source     = "../../modules/nvidia-container-runtime"
  depends_on = [module.kloudlite-crds]
  ssh_params = {
    #    public_ip   = module.k3s-primary-master.public_ip
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    user        = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
  gpu_node_selector = {
    (module.constants.node_labels.node_has_gpu) : "true"
  }
  gpu_node_tolerations = module.constants.gpu_node_tolerations
}

module "kloudlite-operators" {
  count             = var.kloudlite_params.install_operators ? 1 : 0
  source            = "../../modules/kloudlite/helm-kloudlite-operators"
  depends_on        = [module.kloudlite-crds]
  kloudlite_release = var.kloudlite_params.release
  node_selector     = {}
  ssh_params        = {
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}

module "aws-k3s-spot-termination-handler" {
  source              = "../../modules/kloudlite/spot-termination-handler"
  depends_on          = [module.k3s-masters.kubeconfig_with_public_host]
  spot_nodes_selector = module.constants.spot_node_selector
  ssh_params          = {
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
  kloudlite_release = var.kloudlite_params.release
}

module "kloudlite-agent" {
  count                              = var.kloudlite_params.install_agent ? 1 : 0
  source                             = "../../modules/kloudlite/helm-kloudlite-agent"
  kloudlite_account_name             = var.kloudlite_params.agent_vars.account_name
  kloudlite_cluster_name             = var.kloudlite_params.agent_vars.cluster_name
  kloudlite_cluster_token            = var.kloudlite_params.agent_vars.cluster_token
  kloudlite_dns_host                 = var.k3s_masters.public_dns_host
  kloudlite_message_office_grpc_addr = var.kloudlite_params.agent_vars.message_office_grpc_addr
  kloudlite_release                  = var.kloudlite_params.release
  ssh_params                         = {
    public_ip   = module.k3s-masters.k3s_primary_public_ip
    username    = var.k3s_masters.ami_ssh_username
    private_key = module.ssh-rsa-key.private_key
  }
}
