apiVersion: v1
kind: Namespace
metadata:
  name: kloudlite-operators
---
apiVersion: crds.kloudlite.io/v1
kind: HelmChart
metadata:
  name: operators
  namespace: kloudlite-operators
spec:
  chartRepo:
    name: kloudlite
    url: https://kloudlite.github.io/helm-charts

  chartName: kloudlite/kloudlite-operators

  chartVersion: ${kloudlite_release}

  jobVars:
    backOffLimit: 1
    # tolerate any taints
    tolerations:
      - operator: "Exists"

  valuesYaml: |+
    preferOperatorsOnMasterNodes: true
    # tolerate any taints
    tolerations:
    - operator: "Exists"

    operators:
      helmChartsOperator:
        enabled: false