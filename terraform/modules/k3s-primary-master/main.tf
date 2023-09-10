resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

# resource "null_resource" "setup_k3s_on_primary_master" {
#   connection {
#     type        = "ssh"
#     user        = var.ssh_params.user
#     host        = var.public_ip
#     private_key = var.ssh_params.private_key
#   }
#
#   provisioner "remote-exec" {
#     inline = [
#       <<-EOT
#       cat > runner-config.yml <<EOF2
#       runAs: primaryMaster
#       primaryMaster:
#         publicIP: ${var.public_ip}
#         token: ${random_password.k3s_token.result}
#         nodeName: ${var.node_name}
#         SANs:
#           - ${var.public_domain}
#       EOF2
#       sudo ln -sf $PWD/runner-config.yml /runner-config.yml
#       EOT
#     ]
#   }
# }

resource "ssh_resource" "setup_k3s_on_primary_master" {
  host        = var.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  timeout     = "1m"
  retry_delay = "5s"

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
    EOF2
      SANs:
        - ${var.public_domain}
    EOF2
    sudo ln -sf $PWD/runner-config.yml /runner-config.yml
    EOT
  ]
}

resource "ssh_resource" "grab_k8s_config" {
  host        = var.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  timeout     = "2m"
  retry_delay = "5s"

  file {
    source      = "${path.module}/scripts/k8s-user-account.sh"
    destination = "./k8s-user-account.sh"
    permissions = 0755
  }

  commands = [
    <<EOC
    chmod +x ./k8s-user-account.sh
    export KUBECTL='sudo k3s kubectl'

    echo "checking whether /etc/rancher/k3s/k3s.yaml file exists" >> /dev/stderr
    while true; do
      if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then
        echo 'k3s yaml not found, re-checking in 1s' >> /dev/stderr
        sleep 1
        continue
      fi

      echo "/etc/rancher/k3s/k3s.yaml file found" >> /dev/stderr
      break
    done

    echo "checking whether k3s server is accepting connections" >> /dev/stderr
    while true; do
      lines=$(sudo k3s kubectl get nodes | wc -l)

      if [ "$lines" -lt 2 ]; then
        # echo "k3s server is not accepting connections yet, retrying in 1s ..." >> /dev/stderr
        sleep 1
        continue
      fi
      # echo "successful, k3s server is now accepting connections"
      break
    done
    ./k8s-user-account.sh >> /dev/stderr

    kubeconfig=$(cat kubeconfig.yml | sed "s|https://127.0.0.1:6443|https://${var.public_domain}:6443|" | base64 | tr -d '\n')

    printf "$kubeconfig"
    EOC
  ]
}
