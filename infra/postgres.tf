# Expõe um Service por banco para descoberta estável dentro do cluster.
resource "kubernetes_service_v1" "postgres" {
  for_each = local.postgres_databases

  metadata {
    name      = each.value.service_name
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = each.value.service_name
      }
    )
  }

  spec {
    cluster_ip = "None"

    selector = {
      "app.kubernetes.io/name" = each.value.service_name
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Cria um StatefulSet PostgreSQL dedicado para cada microservice que precisa de banco.
resource "kubernetes_stateful_set_v1" "postgres" {
  for_each = local.postgres_databases

  metadata {
    name      = each.value.service_name
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = each.value.service_name
      }
    )
  }

  spec {
    service_name = kubernetes_service_v1.postgres[each.key].metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = each.value.service_name
      }
    }

    template {
      metadata {
        labels = merge(
          local.common_labels,
          {
            "app.kubernetes.io/name" = each.value.service_name
          }
        )
      }

      spec {
        container {
          name              = "postgres"
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5432
            name           = "postgres"
          }

          env {
            name = "POSTGRES_USER"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_secret[each.key].metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_secret[each.key].metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name = "POSTGRES_DB"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_secret[each.key].metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
        labels = merge(
          local.common_labels,
          {
            "app.kubernetes.io/name" = each.value.service_name
          }
        )
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.fiapx,
    kubernetes_secret_v1.postgres_secret,
    kubernetes_service_v1.postgres
  ]
}
