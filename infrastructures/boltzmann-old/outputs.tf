output "k3s_masters" {
  value = module.aws-k3s-HA.k3s_masters
}

output "k3s_token" {
  sensitive = true
  value     = module.aws-k3s-HA.k3s_token
}

output "kubeconfig" {
  sensitive = true
  value     = module.aws-k3s-HA.kubeconfig
}
