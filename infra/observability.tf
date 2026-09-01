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

# ConfigMap com os dashboards Grafana versionados em grafana/dashboards/ do repositório observability.
resource "kubernetes_config_map_v1" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "00-auth.json"             = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/00-auth.json")
    "01-overview.json"         = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/01-overview.json")
    "02-video-upload.json"     = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/02-video-upload.json")
    "03-video-processing.json" = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/03-video-processing.json")
    "04-video-status.json"     = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/04-video-status.json")
    "05-video-download.json"   = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/05-video-download.json")
    "06-notification.json"     = file("${path.module}/../../fiap-14soat-tc-fase5-observability/grafana/dashboards/06-notification.json")
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Instala o Grafana com datasource do Prometheus e dashboards pré-provisionados.
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
    helm_release.prometheus,
    kubernetes_config_map_v1.grafana_dashboards
  ]
}
