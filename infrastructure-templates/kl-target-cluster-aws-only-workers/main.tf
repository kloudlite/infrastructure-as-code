module "kl-worker-nodes-on-aws" {
  source         = "../../terraform/bundles/kl-worker-nodes-on-aws"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  aws_region     = var.aws_region

  ec2_nodepools              = var.ec2_nodepools
  k3s_join_token             = var.k3s_join_token
  k3s_server_public_dns_host = var.k3s_server_public_dns_host
  spot_nodepools             = var.spot_nodepools
  tracker_id                 = "${var.tracker_id}-worker"
  extra_agent_args           = var.extra_agent_args
}
