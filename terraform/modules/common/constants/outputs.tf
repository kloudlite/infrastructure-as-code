output "master_node_taints" {
  value = {
    "node-role.kubernetes.io/master" = {
      effect = "NoSchedule"
      value  = ""
    }
  }
}

output "master_node_tolerations" {
  value = [
    {
      key      = "node-role.kubernetes.io/master"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
}

output "node_label_provider_name" {
  value = "kloudlite.io/provider.name"
}

output "node_labels" {
  value = {
    provider_name          = "kloudlite.io/provider.name"
    provider_region        = "kloudlite.io/provider.region"
    provider_az            = "kloudlite.io/provider.az"
    provider_instance_type = "kloudlite.io/provider.instance-type"

    node_has_role = "kloudlite.io/node.has-role"
    node_has_gpu  = "kloudlite.io/node.has-gpu"
    node_is_spot  = "kloudlite.io/node.is-spot"

    k8s_node_role_worker = "node-role.kubernetes.io/worker"
  }
}