module "kl-master-nodes-on-aws" {
  source                    = "../../terraform/bundles/kl-master-nodes-on-aws"
  aws_access_key            = var.aws_access_key
  aws_region                = var.aws_region
  aws_secret_key            = var.aws_secret_key
  enable_nvidia_gpu_support = var.enable_nvidia_gpu_support
  k3s_masters               = var.k3s_masters
  kloudlite_params          = var.kloudlite_params
  tracker_id                = "${var.tracker_id}-master"
}

module "kl-worker-nodes-on-aws" {
  source         = "../../terraform/bundles/kl-worker-nodes-on-aws"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  aws_region     = var.aws_region

  ec2_nodepools              = var.ec2_nodepools
  k3s_join_token             = module.kl-master-nodes-on-aws.k3s_token
  k3s_server_public_dns_host = module.kl-master-nodes-on-aws.k3s_public_dns_host
  spot_nodepools             = var.spot_nodepools
  tracker_id                 = "${var.tracker_id}-worker"
}
