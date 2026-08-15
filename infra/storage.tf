# Cria o volume persistente compartilhado para uploads e arquivos processados.
resource "kubernetes_persistent_volume_v1" "video_storage" {
  metadata {
    name = "fiapx-video-storage"
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = "fiapx-video-storage"
      }
    )
  }

  spec {
    capacity = {
      storage = "10Gi"
    }

    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = var.video_storage_host_path
        type = "DirectoryOrCreate"
      }
    }
  }
}

# Reserva o volume persistente compartilhado dentro do namespace da solução.
resource "kubernetes_persistent_volume_claim_v1" "video_storage" {
  metadata {
    name      = "fiapx-video-pvc"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = "fiapx-video-pvc"
      }
    )
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.video_storage.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.fiapx,
    kubernetes_persistent_volume_v1.video_storage
  ]
}
