module "worker-nodes-on-gcp" {
  source                      = "../../../terraform/bundles/gcp/worker-nodes"
  allow_incoming_http_traffic = var.allow_incoming_http_traffic
  availability_zone           = var.availability_zone
  bootvolume_size             = var.bootvolume_size
  bootvolume_type             = var.bootvolume_type
  k3s_extra_agent_args        = var.k3s_extra_agent_args
  k3s_join_token              = var.k3s_join_token
  k3s_server_public_dns_host  = var.k3s_server_public_dns_host
  kloudlite_release           = var.kloudlite_release
  machine_type                = var.machine_type
  name_prefix                 = var.name_prefix
  network                     = var.network
  nodepool_name               = var.nodepool_name
  nodes                       = var.nodes
  provision_mode              = var.provision_mode
}