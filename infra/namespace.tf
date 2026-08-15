# Centraliza labels comuns para todos os recursos compartilhados do cluster.
locals {
  common_labels = {
    "app.kubernetes.io/part-of"    = "raceforce-video-platform"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }
}

# Cria o namespace principal onde a infraestrutura local será provisionada.
resource "kubernetes_namespace_v1" "fiapx" {
  metadata {
    name = var.namespace

    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = var.namespace
      }
    )

    annotations = {
      "project-name" = var.project_name
    }
  }
}
