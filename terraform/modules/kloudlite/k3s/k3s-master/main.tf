locals {
  primary_master_role   = "primary-master"
  secondary_master_role = "secondary-master"

  node_taints = flatten([
    for taint in var.node_taints : [
      "${taint.key}=${taint.value}:${taint.effect}",
    ]
  ])
}

resource "random_password" "k3s_server_token" {
  length  = 64
  special = false
}

resource "random_password" "k3s_agent_token" {
  length  = 64
  special = false
}

module "kloudlite-k3s-templates" {
  source = "../k3s-templates"
}

locals {
  #  backup_crontab_schedule = "1 2/${2 * length(var.master_nodes)} * * *" # explanation https://crontab.guru/#1_1/2_*_*_*
  backup_crontab_schedule = "1/11 * * * *" # explanation https://crontab.guru/#1/8_*_*_*_* # every 11th minute

  k3s_server_extra_args = {
    for k, v in var.master_nodes : k => concat(
      [
        "--token", random_password.k3s_server_token.result,
        "--agent-token", random_password.k3s_agent_token.result,
        "--disable-helm-controller",
        "--disable", "traefik",
        # "--disable", "servicelb",
        "--node-external-ip", v.public_ip,
        "--tls-san-security",
        "--flannel-external-ip",
        "--cluster-domain", var.cluster_internal_dns_host,
        # [read more here](https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/#system-reserved)
        "--kubelet-arg", "--system-reserved=cpu=100m,memory=200Mi,ephemeral-storage=1Gi,pid=1000"
      ],
      var.k3s_service_cidr != "" ? ["--service-cidr", var.k3s_service_cidr] : [],
      var.backup_to_s3.enabled && v.role == "primary-master" ? [
        "--etcd-s3",
        "--etcd-s3-endpoint", var.backup_to_s3.endpoint,

        "--etcd-s3-bucket", var.backup_to_s3.bucket_name,
        "--etcd-s3-region", var.backup_to_s3.bucket_region,
        "--etcd-s3-folder", var.backup_to_s3.bucket_folder,

        "--etcd-snapshot-compress",
        "--etcd-snapshot-schedule-cron", local.backup_crontab_schedule,
      ] : [],
      var.extra_server_args
    )
  }
}

resource "ssh_resource" "k3s_primary_master" {
  for_each    = { for k, v in var.master_nodes : k => v if v.role == local.primary_master_role }
  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [
    random_password.k3s_server_token,
    random_password.k3s_agent_token,
  ]

  triggers = {
    always_run = sha1(join(",", [
      jsonencode(each.value.node_labels),
      jsonencode(local.k3s_server_extra_args[each.key]),
    ]))
  }

  timeout     = "3m"
  retry_delay = "5s"

  #  when = "create"
  when = "create"

  file {
    source      = "${path.module}/scripts/k8s-user-account.sh"
    destination = "./k8s-user-account.sh"
    permissions = 0755
  }

  commands = [
    <<-EOT
    echo "setting up k3s on primary master"
    cat > /tmp/runner-config.yml <<EOF2
k3s_flags: ${jsonencode(concat(
    [
      "server",
      "--cluster-init",
      "--flannel-backend", "wireguard-native",
      "--write-kubeconfig-mode", "6444",
      "--node-label", "kloudlite.io/node.public-ip=${each.value.public_ip}",
      "--node-label", "kloudlite.io/node.name=${each.key}",
      "--tls-san", var.public_dns_host,
      "--tls-san", each.value.public_ip,
    ],
    flatten([for k, v in each.value.node_labels : ["--node-label", "${k}=${v}"]]),
    local.k3s_server_extra_args[each.key],
))}

EOF2

  sudo mv /tmp/runner-config.yml ${module.kloudlite-k3s-templates.kloudlite_config_directory}/runner-config.yml
  # sudo systemctl restart kloudlite-k3s.service
EOT
]
}

resource "ssh_resource" "k3s_primary_master_upgrade" {
  for_each = { for k, v in var.master_nodes : k => v if v.role == local.primary_master_role }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [ssh_resource.k3s_primary_master]

  when = "create"
  triggers = {
    when_kloudlite_release_changes = each.value.kloudlite_release
  }

  timeout     = "2m"
  retry_delay = "2s"

  commands = [
    <<EOT
# sudo kloudlite-install-or-upgrade.sh
# sudo systemctl restart kloudlite-k3s.service
EOT
  ]
}

locals {
  primary_master_node_name = one([
    for node_name, node_cfg in var.master_nodes : node_name
    if node_cfg.role == local.primary_master_role
  ])
}

resource "null_resource" "wait_till_k3s_primary_server_is_ready" {
  for_each = { for k, v in var.master_nodes : k => v if v.role == local.primary_master_role }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = var.ssh_params.user
    private_key = var.ssh_params.private_key
  }

  depends_on = [ssh_resource.k3s_primary_master]

  provisioner "remote-exec" {
    inline = [
      <<EOC
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

    echo "[#] k3s server is now fully ready, provisioning a new revocable kubeconfig"
    chmod +x ./k8s-user-account.sh
    ./k8s-user-account.sh kubeconfig.yml
EOC
    ]
  }
}

resource "ssh_resource" "create_revocable_kubeconfig" {
  for_each = { for k, v in var.master_nodes : k => v if v.role == local.primary_master_role }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [null_resource.wait_till_k3s_primary_server_is_ready]

  timeout     = "20s"
  retry_delay = "2s"

  when = "create"

  commands = [
    <<EOT
cat kubeconfig.yml | base64 | tr -d '\n'
EOT
  ]
}

resource "ssh_resource" "k3s_secondary_masters" {
  for_each = { for k, v in var.master_nodes : k => v if v.role == local.secondary_master_role }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [ssh_resource.k3s_primary_master]

  triggers = {
    always_run = sha1(join(",", [
      jsonencode(each.value.node_labels), jsonencode(local.k3s_server_extra_args[each.key])
    ]))
  }

  when = "create"

  timeout     = "2m"
  retry_delay = "2s"

  commands = [
    <<EOT
if [ "${var.restore_from_latest_s3_snapshot}" == "true" ]; then
  # sudo systemctl stop kloudlite-k3s.service
  sudo rm -rf /var/lib/rancher/k3s/server/db/
  # sudo systemctl start kloudlite-k3s.service
fi

cat > /tmp/runner-config.yml<<EOF2
k3s_flags: ${jsonencode(concat(
    [
      "server", "--server", "https://${var.master_nodes[local.primary_master_node_name].public_ip}:6443",
      "--flannel-backend", "wireguard-native",
      "--write-kubeconfig-mode", "6444",
      "--node-label", "kloudlite.io/node.public-ip=${each.value.public_ip}",
      "--node-label", "kloudlite.io/node.name=${each.key}",
      "--tls-san", var.public_dns_host,
      "--tls-san", each.value.public_ip,
    ],
    flatten([for k, v in each.value.node_labels : ["--node-label", "${k}=${v}"]]),
    local.k3s_server_extra_args[each.key],
))}
EOF2

sudo mv /tmp/runner-config.yml ${module.kloudlite-k3s-templates.kloudlite_config_directory}/runner-config.yml
# sudo systemctl restart kloudlite-k3s.service
EOT
]
}

resource "ssh_resource" "k3s_secondary_masters_upgrade" {
  for_each = { for k, v in var.master_nodes : k => v if v.role == local.secondary_master_role }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  depends_on = [ssh_resource.k3s_secondary_masters]

  when = "create"
  triggers = {
    when_kloudlite_release_changes = each.value.kloudlite_release
  }

  timeout     = "2m"
  retry_delay = "2s"

  commands = [
    <<EOT
# sudo kloudlite-install-or-upgrade.sh
# sudo systemctl restart kloudlite-k3s.service
EOT
  ]
}

// these steps need to be followed: https://docs.k3s.io/cli/etcd-snapshot
resource "ssh_resource" "k3s_restore_step_1_restore_primary_master" {
  for_each = {
    for k, v in var.master_nodes : k => v
    if v.role == local.primary_master_role && var.restore_from_latest_s3_snapshot == true
  }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  timeout     = "3m"
  retry_delay = "5s"

  commands = [
    <<-EOT
    if [ "${var.restore_from_latest_s3_snapshot}" != "true" ]; then
      exit 0
    fi

    # sudo systemctl stop kloudlite-k3s.service
    cat > k3s-list-snapshots.sh <<'EOF2'
sudo k3s etcd-snapshot ls \
  --s3 \
  --s3-region="${var.backup_to_s3.bucket_region}" \
  --s3-bucket="${var.backup_to_s3.bucket_name}" \
  --s3-folder="${var.backup_to_s3.bucket_folder}"
EOF2

    echo "listing all snapshots: "
    bash k3s-list-snapshots.sh
    latest_snapshot=$(bash k3s-list-snapshots.sh 2> /dev/null | tail -n +2 | sort -k 3 -r | head -n +1 | awk '{print $1}')
    [ -z "$latest_snapshot" ] && echo "no snapshot found, exiting ..." && exit 1

    sudo k3s server \
      --cluster-init \
      --cluster-reset \
      --cluster-reset-restore-path "$latest_snapshot" \
          --etcd-s3 \
          --etcd-s3-region="${var.backup_to_s3.bucket_region}" \
          --etcd-s3-bucket="${var.backup_to_s3.bucket_name}" \
          --etcd-s3-folder="${var.backup_to_s3.bucket_folder}"

      # k3s server complains about it, after restoring
    sudo rm /var/lib/rancher/k3s/server/cred/passwd
#    sudo systemctl start kloudlite-k3s.service
EOT
  ]
}

resource "ssh_resource" "k3s_restore_step_2_stop_k3s_on_secondary_masters" {
  for_each = {
    for k, v in var.master_nodes : k => v
    if v.role == local.secondary_master_role && var.restore_from_latest_s3_snapshot == true
  }

  depends_on = [ssh_resource.k3s_restore_step_1_restore_primary_master]

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  when = "create"

  timeout     = "2m"
  retry_delay = "2s"

  commands = [
    <<EOC

if [ "${var.restore_from_latest_s3_snapshot}" != "true" ]; then
  exit 0
fi

# sudo systemctl stop kloudlite-k3s.service
# sudo rm -rf /var/lib/rancher/k3s/server/db/

EOC
  ]
}

resource "ssh_resource" "k3s_restore_step_3_start_k3s_on_primary_master" {
  for_each = {
    for k, v in var.master_nodes : k => v
    if v.role == local.primary_master_role && var.restore_from_latest_s3_snapshot == true
  }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  timeout     = "3m"
  retry_delay = "5s"

  depends_on = [ssh_resource.k3s_restore_step_2_stop_k3s_on_secondary_masters]

  commands = [
    <<-EOT
    if [ "${var.restore_from_latest_s3_snapshot}" != "true" ]; then
      exit 0
    fi
    # sudo systemctl start kloudlite-k3s.service
EOT
  ]
}

resource "ssh_resource" "k3s_restore_step_4_start_k3s_on_secondary_masters" {
  for_each = {
    for k, v in var.master_nodes : k => v
    if v.role == local.secondary_master_role && var.restore_from_latest_s3_snapshot == true
  }

  host        = each.value.public_ip
  user        = var.ssh_params.user
  private_key = var.ssh_params.private_key

  timeout     = "3m"
  retry_delay = "5s"

  depends_on = [ssh_resource.k3s_restore_step_3_start_k3s_on_primary_master]

  commands = [
    <<-EOT
    if [ "${var.restore_from_latest_s3_snapshot}" != "true" ]; then
      exit 0
    fi
    sudo systemctl start kloudlite-k3s.service
EOT
  ]
}
