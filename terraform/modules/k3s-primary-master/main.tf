resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

resource "ssh_resource" "setup_k3s_on_primary_master" {
  host        = var.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  connection {
    type        = "ssh"
    host        = var.public_ip
    user        = var.ssh_params.user
    private_key = var.ssh_params.private_key
  }

  timeout     = "1m"
  retry_delay = "5s"

  when = "create"

  file {
    source      = "${path.module}/scripts/k8s-user-account.sh"
    destination = "./k8s-user-account.sh"
    permissions = 0755
  }

  commands = [
    <<-EOT
    echo "setting up k3s on primary master"
    cat > runner-config.yml <<EOF2
runAs: primaryMaster
primaryMaster:
  publicIP: ${var.public_ip}
  token: ${random_password.k3s_token.result}
  nodeName: ${var.node_name}
  labels: ${jsonencode(var.node_labels)}
  SANs:
    - ${var.public_domain}
EOF2

    sudo ln -sf $PWD/runner-config.yml /runner-config.yml
EOT
  ]
}

resource "null_resource" "wait_till_k3s_server_is_ready" {
  #  host        = var.public_ip
  #  user        = var.ssh_params.user
  #  private_key = var.ssh_params.private_key

  connection {
    type        = "ssh"
    host        = var.public_ip
    user        = var.ssh_params.user
    private_key = var.ssh_params.private_key
  }

  depends_on = [ssh_resource.setup_k3s_on_primary_master]

  #  when = "create"
  #  timeout     = "2m"
  #  retry_delay = "5s"


  provisioner "remote-exec" {
    inline = [
      <<EOC
    chmod +x ./k8s-user-account.sh
    export KUBECTL='sudo k3s kubectl'

    echo "checking whether /etc/rancher/k3s/k3s.yaml file exists"
    while true; do
      if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then
        echo 'k3s yaml not found, re-checking in 1s'
        sleep 1
        continue
      fi

      echo "/etc/rancher/k3s/k3s.yaml file found"
      break
    done

    echo "checking whether k3s server is accepting connections"
    while true; do
      lines=$($KUBECTL get nodes | wc -l)

      if [ "$lines" -lt 2 ]; then
        echo "k3s server is not accepting connections yet, retrying in 1s ..."
        sleep 1
        continue
      fi
      echo "successful, k3s server is now accepting connections"
      break
    done

    ./k8s-user-account.sh kubeconfig.yml
EOC
    ]
  }

}

resource "ssh_resource" "copy_kubeconfig" {
  host        = var.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [null_resource.wait_till_k3s_server_is_ready]

  timeout     = "30s"
  retry_delay = "2s"

  when = "create"

  commands = [
    <<EOT
cat kubeconfig.yml | base64 | tr -d '\n'
if [ "${var.disable_ssh}" == "true" ]; then
  sudo systemctl disable sshd.service
  sudo systemctl stop sshd.service
  sudo rm -f ~/.ssh/authorized_keys
fi
EOT
  ]
}
