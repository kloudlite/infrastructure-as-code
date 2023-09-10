resource "null_resource" "setup_k3s_on_secondary_masters" {
  for_each = { for idx, config in var.secondary_masters : idx => config }
  connection {
    type        = "ssh"
    user        = each.value.ssh_params.user
    host        = each.value.public_ip
    private_key = each.value.ssh_params.private_key
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOC
      cat > runner-config.yml <<EOF2
      runAs: secondaryMaster
      secondaryMaster:
        publicIP: ${each.value.public_ip}
        serverIP: ${var.primary_master_public_ip}
        token: ${var.k3s_token}
        nodeName: ${each.key}
        labels: ${jsonencode(each.value.node_labels)}
        SANs:
          - ${var.public_domain}
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
