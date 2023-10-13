locals {
  constants = {
    master_node_taints = {
      masters = {
        effect = "NoExecute"
        value  = "true"
      }
    }

    node_labels = {
      provider_name          = "kloudlite.io/provider.name"
      provider_region        = "kloudlite.io/provider.region"
      provider_az            = "kloudlite.io/provider.az"
      provider_instance_type = "kloudlite.io/provider.instance-type"

      node_has_role = "kloudlite.io/node.has-role"
      node_has_gpu  = "kloudlite.io/node.has-gpu"
      node_is_spot  = "kloudlite.io/node.is-spot"
    }
  }
}
