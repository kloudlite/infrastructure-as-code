output "k3s_masters" {
  value = module.kl-master-nodes-on-aws.k3s_masters
}

output "k3s_token" {
  sensitive = true
  value     = module.kl-master-nodes-on-aws.k3s_token
}

output "kubeconfig" {
  sensitive = true
  value     = module.kl-master-nodes-on-aws.kubeconfig
}