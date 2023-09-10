resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}