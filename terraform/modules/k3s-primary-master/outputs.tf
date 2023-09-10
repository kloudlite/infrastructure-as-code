output "k3s_token" {
  value = random_password.k3s_token.result
}

output "public_ip" {
  value = var.public_ip
}

output "kubeconfig" {
  value = chomp(ssh_resource.grab_k8s_config.result)
}
