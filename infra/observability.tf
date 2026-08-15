# Instala o Prometheus para coleta local de métricas do ambiente compartilhado.
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = kubernetes_namespace_v1.fiapx.metadata[0].name
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    file("${path.module}/../helm-values/prometheus-values.yaml")
  ]

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Instala o Grafana com datasource do Prometheus pré-configurado para uso local.
resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = kubernetes_namespace_v1.fiapx.metadata[0].name
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    file("${path.module}/../helm-values/grafana-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace_v1.fiapx,
    helm_release.prometheus
  ]
}
