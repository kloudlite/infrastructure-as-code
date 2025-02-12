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
  source = "../../../modules/common/constants"
}

module "ssh-rsa-key" {
  source     = "../../../modules/common/ssh-rsa-key"
  depends_on = [null_resource.variable_validations]
}

resource "null_resource" "save_ssh_key" {
  count = length(var.save_ssh_key_to_path) > 0 ? 1 : 0

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
  source     = "../../../modules/aws/security-groups"
  depends_on = [null_resource.variable_validations]

  tracker_id = var.tracker_id
  vpc_id     = var.vpc_id

  create_for_k3s_masters = true

  allow_incoming_http_traffic = true
  expose_k8s_node_ports       = true
}

module "kloudlite-k3s-templates" {
  source = "../../../modules/kloudlite/k3s/k3s-templates"
}

module "aws-amis" {
  source = "../../../modules/aws/AMIs"
}

module "k3s-master-instances" {
  source   = "../../../modules/aws/ec2-node"
  for_each = { for name, cfg in var.k3s_masters.nodes : name => cfg }

  ami           = var.k3s_masters.ami
  instance_type = var.k3s_masters.instance_type

  availability_zone    = each.value.availability_zone
  iam_instance_profile = var.k3s_masters.iam_instance_profile
  is_nvidia_gpu_node   = var.enable_nvidia_gpu_support
  node_name            = each.key
  root_volume_size     = var.k3s_masters.root_volume_size
  root_volume_type     = var.k3s_masters.root_volume_type
  security_groups      = module.aws-security-groups.sg_for_k3s_masters_names
  last_recreated_at    = each.value.last_recreated_at
  ssh_key_name         = aws_key_pair.k3s_nodes_ssh_key.key_name
  tracker_id           = var.tracker_id
  tags                 = var.tags
  user_data_base64 = base64encode(templatefile(module.kloudlite-k3s-templates.k3s-vm-setup-template-path, {
    kloudlite_release             = var.kloudlite_params.release
    k3s_download_url              = ""
    kloudlite_runner_download_url = ""
    kloudlite_config_directory    = module.kloudlite-k3s-templates.kloudlite_config_directory
  }))
  vpc = {
    subnet_id              = each.value.vpc_subnet_id
    vpc_security_group_ids = module.aws-security-groups.sg_for_k3s_masters_ids
  }
}

module "kloudlite-k3s-masters" {
  source                    = "../../kloudlite-k3s-masters"
  backup_to_s3              = var.k3s_masters.backup_to_s3
  cloudflare                = var.k3s_masters.cloudflare
  cluster_internal_dns_host = var.k3s_masters.cluster_internal_dns_host
  enable_nvidia_gpu_support = var.enable_nvidia_gpu_support
  kloudlite_params          = var.kloudlite_params
  master_nodes = {
    for name, cfg in var.k3s_masters.nodes : name => {
      role : cfg.role,
      public_ip : module.k3s-master-instances[name].public_ip,
      node_labels : {
        (module.constants.node_labels.kloudlite_release) : cfg.kloudlite_release,
        (module.constants.node_labels.provider_name) : "aws",
        (module.constants.node_labels.provider_region) : var.aws_region,
        (module.constants.node_labels.provider_az) : cfg.availability_zone,
        (module.constants.node_labels.node_has_role) : cfg.role,
        (module.constants.node_labels.provider_aws_instance_profile_name) : var.k3s_masters.iam_instance_profile,
        (module.constants.node_labels.provider_instance_type) : var.k3s_masters.instance_type,
      }
      availability_zone = cfg.availability_zone,
      last_recreated_at = cfg.last_recreated_at,
      kloudlite_release = cfg.kloudlite_release,
    }
  }
  public_dns_host              = var.k3s_masters.public_dns_host
  restore_from_latest_snapshot = var.k3s_masters.restore_from_latest_snapshot
  ssh_private_key              = module.ssh-rsa-key.private_key

  ssh_username = var.k3s_masters.ssh_username

  taint_master_nodes      = var.k3s_masters.taint_master_nodes
  tracker_id              = var.tracker_id
  save_kubeconfig_to_path = var.save_kubeconfig_to_path
  cloudprovider_name      = "aws"
  cloudprovider_region    = var.aws_region
  k3s_service_cidr        = var.k3s_service_cidr
}
