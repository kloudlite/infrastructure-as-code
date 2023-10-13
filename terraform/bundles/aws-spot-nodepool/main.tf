module "ssh-rsa-key" {
  source = "../../modules/common/ssh-rsa-key"
}

resource "random_id" "id" {
  byte_length = 4
}

resource "aws_key_pair" "k3s_nodes_ssh_key" {
  key_name   = "${var.tracker_id}-${random_id.id.hex}-ssh-key"
  public_key = module.ssh-rsa-key.public_key
}

module "spot-fleet-request" {
  source                       = "../../modules/aws/spot-fleet-request"
  for_each                     = {for name, cfg in var.nodes : name => cfg}
  ami                          = var.ami
  availability_zone            = var.availability_zone
  cpu_node                     = var.cpu_node
  gpu_node                     = var.gpu_node
  iam_instance_profile         = var.iam_instance_profile
  node_name                    = each.key
  tracker_id                   = var.tracker_id
  root_volume_size             = var.root_volume_size
  root_volume_type             = var.root_volume_type
  security_groups              = var.security_groups
  spot_fleet_tagging_role_name = var.spot_fleet_tagging_role_name
  ssh_key_name                 = var.ssh_key_name
  user_data                    = each.value.user_data
  last_recreated_at            = each.value.last_recreated_at != null ? each.value.last_recreated_at : 0
}
