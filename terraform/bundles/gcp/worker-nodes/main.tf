module "ssh-rsa-key" {
  source = "../../../modules/common/ssh-rsa-key"
}

resource "null_resource" "save_ssh_key" {
  count = length(var.save_ssh_key_to_path) > 0 ? 1 : 0

  provisioner "local-exec" {
    quiet   = true
    command = "echo '${module.ssh-rsa-key.private_key}' > ${var.save_ssh_key_to_path} && chmod 600 ${var.save_ssh_key_to_path}"
  }
}

module "constants" {
  source = "../../../modules/common/constants"
}

module "kloudlite-k3s-templates" {
  source = "../../../modules/kloudlite/k3s/k3s-templates"
}

#resource "random_id" "id" {
#  byte_length = 6
#}

locals {
  k3s_worker_tags = ["${var.name_prefix}-${var.nodepool_name}-k3s-worker"]
}

module "worker-nodes-firewall" {
  source = "../../../modules/gcp/firewall"

  for_worker_nodes            = true
  network_name                = var.network
  target_tags                 = local.k3s_worker_tags
  allow_incoming_http_traffic = var.allow_incoming_http_traffic
  allow_node_ports            = false
  name_prefix                 = "${var.name_prefix}-${var.nodepool_name}-fw"
  allow_ssh                   = var.allow_ssh
}

module "worker-nodes" {
  source = "../../../modules/gcp/machine"

  for_each = { for name, cfg in var.nodes : name => cfg }

  machine_type      = var.machine_type
  service_account   = var.service_account
  name              = "${var.name_prefix}-${var.nodepool_name}-${each.key}"
  provision_mode    = var.provision_mode
  ssh_key           = module.ssh-rsa-key.public_key
  availability_zone = var.availability_zone
  network           = var.network

  network_tags = local.k3s_worker_tags
  labels       = var.labels

  startup_script = templatefile(module.kloudlite-k3s-templates.k3s-agent-template-path, {
    kloudlite_config_directory = module.kloudlite-k3s-templates.kloudlite_config_directory

    vm_setup_script = templatefile(module.kloudlite-k3s-templates.k3s-vm-setup-template-path, {
      # kloudlite_release             = var.kloudlite_release
      k3s_download_url              = var.k3s_download_url
      kloudlite_runner_download_url = var.kloudlite_runner_download_url

      kloudlite_config_directory = module.kloudlite-k3s-templates.kloudlite_config_directory
    })

    tf_k3s_masters_dns_host = var.k3s_server_public_dns_host
    tf_k3s_token            = var.k3s_join_token
    tf_node_taints          = []
    tf_node_labels = merge(var.node_labels, {
      (module.constants.node_labels.provider_az)   = var.availability_zone
      (module.constants.node_labels.node_has_role) = "agent"
      (module.constants.node_labels.nodepool_name) : var.nodepool_name
      (module.constants.node_labels.provider_aws_instance_profile_name) : ""
      },
      var.provision_mode == "SPOT" ? { (module.constants.node_labels.node_is_spot) = "true" } : {},
      #            var.nvidia_gpu_enabled == true ? { (module.constants.node_labels.node_has_gpu) : "true" } : {}
    )
    tf_node_name                 = "${var.nodepool_name}-${each.key}"
    tf_use_cloudflare_nameserver = true
    tf_extra_agent_args          = var.k3s_extra_agent_args
  })

  bootvolume_type = var.bootvolume_type
  bootvolume_size = var.bootvolume_size

  additional_disk = {
    for k, v in(var.additional_disk != null ? var.additional_disk : {}) :
    "${var.name_prefix}-${var.nodepool_name}-${each.key}-${k}" => v
  }

  machine_state = var.machine_state
}

