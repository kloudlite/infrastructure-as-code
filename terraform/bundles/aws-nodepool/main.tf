locals {
  nodes_cfg = {
    for idx, config in var.nodes : idx => {
      ami                  = var.ami
      az                   = var.availability_zone
      instance_type        = var.instance_type
      root_volume_size     = var.root_volume_size
      root_volume_type     = var.root_volume_type
      with_elastic_ip      = false
      security_groups      = var.security_groups
      iam_instance_profile = var.iam_instance_profile

      recreate = config.recreate
    }
  }
}

module "ec2-nodes" {
  source       = "../../modules/aws/ec2-nodes"
  nodes_config = local.nodes_cfg
  ssh_key_name = var.ssh_key_name
}