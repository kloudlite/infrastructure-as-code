module "aws-k3s-HA" {
  source         = "../../../terraform/bundles/aws-k3s-HA"
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

  kloudlite_release  = var.kloudlite_release
  taint_master_nodes = var.taint_master_nodes
}
