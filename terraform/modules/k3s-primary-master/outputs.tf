output "k3s_token" {
  value = random_password.k3s_token.result
}

output "public_ip" {
  value = var.public_ip
}

output "kubeconfig_with_public_ip" {
  value = base64encode(replace(chomp(ssh_resource.grab_k8s_config.result), "https://127.0.0.1", "https://${var.public_ip}"))
}

output "kubeconfig_with_public_host" {
  value = base64encode(replace(chomp(ssh_resource.grab_k8s_config.result), "https://127.0.0.1", "https://${var.public_domain}"))
}
