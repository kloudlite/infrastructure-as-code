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
