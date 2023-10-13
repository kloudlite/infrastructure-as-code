output "k3s-agent-template" {
  value = file("${path.module}/k3s-agent-setup.sh")
}