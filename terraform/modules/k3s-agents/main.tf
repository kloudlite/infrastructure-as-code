resource "null_resource" "setup_k3s_on_agents" {
  for_each = {for idx, config in var.agent_nodes : idx => config}
  connection {
    type        = "ssh"
    user        = each.value.ssh_params.user
    host        = each.value.public_ip
    private_key = each.value.ssh_params.private_key
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOC
      cat >runner-config.yml <<EOF2
      runAs: agent
      agent:
        publicIP: ${each.value.public_ip}
        serverIP: ${var.k3s_server_host}
        token: ${var.k3s_token}
        labels: ${jsonencode(each.value.node_labels)}
        nodeName: ${each.key}
      EOF2

      sudo ln -sf $PWD/runner-config.yml /runner-config.yml
      if [ "${var.disable_ssh}" == "true" ]; then
        sudo systemctl disable sshd.service
        sudo systemctl stop sshd.service
        sudo rm -f ~/.ssh/authorized_keys
      fi
      EOC
    ]
  }
}
