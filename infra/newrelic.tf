locals {
  new_relic_cluster_name = length(trimspace(var.new_relic_cluster_name_override)) > 0 ? var.new_relic_cluster_name_override : var.eks_cluster_name
}

resource "helm_release" "newrelic_bundle" {
  count            = var.enable_new_relic ? 1 : 0
  name             = "newrelic-bundle"
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  namespace        = var.new_relic_namespace
  create_namespace = true

  timeout         = var.new_relic_helm_timeout_seconds
  wait            = var.new_relic_helm_wait
  wait_for_jobs   = var.new_relic_helm_wait_for_jobs
  atomic          = var.new_relic_helm_atomic
  cleanup_on_fail = var.new_relic_helm_cleanup_on_fail

  # Configuracoes globais
  set {
    name  = "global.licenseKey"
    value = var.new_relic_license_key
  }

  set {
    name  = "global.cluster"
    value = local.new_relic_cluster_name
  }

  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  # Coleta de metricas base do Kubernetes
  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "kubeEvents.enabled"
    value = "true"
  }

  # Prometheus: manter coleta com low data mode no agente
  set {
    name  = "newrelic-prometheus-agent.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-prometheus-agent.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-prometheus-agent.config.kubernetes.integrations_filter.enabled"
    value = "false"
  }

  # eBPF: eAPM habilitado e metricas de rede desabilitadas no MVP
  set {
    name  = "nr-ebpf-agent.enabled"
    value = "true"
  }

  set {
    name  = "nr-ebpf-agent.networkMetricsReporting"
    value = "false"
  }

  # Logs do cluster com low data mode
  set {
    name  = "logging.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.lowDataMode"
    value = "true"
  }

  # Garante que so instala depois que os nodes estiverem prontos
  depends_on = [
    aws_eks_node_group.eks_node_group,
    aws_eks_access_policy_association.ci_cluster_admin
  ]
}