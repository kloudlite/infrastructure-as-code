module "aws-k3s-HA" {
  source         = "../../terraform/bundles/aws-k3s-HA"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  aws_region     = var.aws_region

  aws_iam_instance_profile_role = var.aws_iam_instance_profile_role
  aws_ami                       = var.aws_ami
  aws_ami_ssh_username          = "ubuntu"

  ec2_nodes_config = var.ec2_nodes_config

  cloudflare = {
    enabled   = true
    api_token = var.cloudflare_api_token
    domain    = var.cloudflare_domain
    zone_id   = var.cloudflare_zone_id
  }
  k3s_server_dns_hostname = var.cloudflare_domain

  spot_settings = {
    enabled                      = var.spot_settings.enabled
    spot_fleet_tagging_role_name = var.spot_settings.spot_fleet_tagging_role_name
  }
  spot_nodes_config = var.spot_nodes_config

  disable_ssh      = var.disable_ssh
  k3s_backup_to_s3 = {
    enabled = false
  }

  taint_master_nodes = var.taint_master_nodes
  kloudlite          = {
    release            = var.kloudlite_release
    install_crds       = true
    install_csi_driver = true
    install_operators  = true
    install_agent      = var.kloudlite_agent_vars.install
    agent_vars         = {
      account_name             = var.kloudlite_agent_vars.account_name
      cluster_name             = var.kloudlite_agent_vars.cluster_name
      cluster_token            = var.kloudlite_agent_vars.cluster_token
      dns_host                 = var.kloudlite_agent_vars.dns_host
      message_office_grpc_addr = var.kloudlite_agent_vars.message_office_grpc_addr
    }
  }
  aws_nvidia_gpu_ami        = ""
  enable_nvidia_gpu_support = false
}