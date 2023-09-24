resource "kubectl_manifest" "service_account" {
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-spot-k3s-termination-handler
  namespace: kube-system
YAML
}

resource "kubectl_manifest" "cluster_role_binding" {
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aws-spot-k3s-termination-handler-rb
subjects:
  - kind: ServiceAccount
    name: aws-spot-k3s-termination-handler
    namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: "ClusterRole"
  name: cluster-admin
YAML
}

resource "kubectl_manifest" "daemonset" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: &name aws-spot-k3s-termination-handler
  namespace: kube-system
  labels:
    installed-by: kloudlite
spec:
  selector:
    matchLabels:
      name: *name
  template:
    metadata:
      labels:
        name: *name
    spec:
      serviceAccountName: aws-spot-k3s-termination-handler
      nodeSelector: ${jsonencode(var.spot_nodes_selector)}
      containers:
      - name: main
        image: ghcr.io/kloudlite/platform/aws-spot-k3s-termination-handler:v1.0.5-nightly
        env:
         - name: NODE_NAME
           valueFrom:
             fieldRef:
               fieldPath: spec.nodeName
         - name: DEBUG
           value: "true"
        resources:
          limits:
            memory: 50Mi
            cpu: 50m
          requests:
            memory: 20Mi
            cpu: 20m
      terminationGracePeriodSeconds: 10
YAML
}