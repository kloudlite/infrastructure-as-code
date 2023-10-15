output "k3s_masters" {
  value = {
    for node_name, public_ip in module.k3s-masters-nodepool.public_ips : node_name => {
      public_ip         = public_ip
      availability_zone = var.k3s_masters.nodes[node_name].availability_zone
    }
  }
}

output "k3s_token" {
  sensitive = true
  value     = module.k3s-primary-master.k3s_token
}

output "kubeconfig" {
  sensitive = true
  value     = module.k3s-primary-master.kubeconfig_with_public_host
}