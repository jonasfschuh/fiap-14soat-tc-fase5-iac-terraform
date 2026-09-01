# Define filas e componentes padrão para o RabbitMQ local.
locals {
  rabbitmq_definitions = jsonencode({
    users = [
      {
        name              = var.rabbitmq_user
        password_hash     = "kKGyw62FPyqyox32yhwdV7IjyUvpbTZ3C+dkZINpxdtFkHNZ"
        hashing_algorithm = "rabbit_password_hashing_sha256"
        tags              = "administrator"
      }
    ]
    vhosts = [
      {
        name = var.rabbitmq_vhost
      }
    ]
    permissions = [
      {
        user      = var.rabbitmq_user
        vhost     = var.rabbitmq_vhost
        configure = ".*"
        write     = ".*"
        read      = ".*"
      }
    ]
    exchanges = [
      {
        name        = "video.events"
        vhost       = var.rabbitmq_vhost
        type        = "topic"
        durable     = true
        auto_delete = false
        internal    = false
        arguments   = {}
      }
    ]
    queues = [
      # ── video-upload-service ──────────────────────────────────────────────
      {
        name        = "video-uploaded"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments = {
          "x-dead-letter-exchange"    = "video.events"
          "x-dead-letter-routing-key" = "video.uploaded.dlq"
        }
      },
      {
        name        = "video-uploaded-dlq"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      {
        name        = "video-processed"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments = {
          "x-dead-letter-exchange"    = "video.events"
          "x-dead-letter-routing-key" = "video.processed.dlq"
        }
      },
      {
        name        = "video-processed-dlq"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      # ── video-processing-service / video-status-service / notification-service ──
      {
        name        = "video-events"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments = {
          "x-dead-letter-exchange"    = "video.events"
          "x-dead-letter-routing-key" = "video.events.dlq"
        }
      },
      {
        name        = "video-events-dlq"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      # ── video-status-service (fila dedicada para video.uploaded) ──────────
      {
        name        = "video-status-uploaded"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments = {
          "x-dead-letter-exchange"    = "video.events"
          "x-dead-letter-routing-key" = "video.status.uploaded.dlq"
        }
      },
      {
        name        = "video-status-uploaded-dlq"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      }
    ]
    bindings = [
      # ── video-uploaded ────────────────────────────────────────────────────
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-uploaded"
        destination_type = "queue"
        routing_key      = "video.uploaded"
        arguments        = {}
      },
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-uploaded-dlq"
        destination_type = "queue"
        routing_key      = "video.uploaded.dlq"
        arguments        = {}
      },
      # ── video-processed ───────────────────────────────────────────────────
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-processed"
        destination_type = "queue"
        routing_key      = "video.processed"
        arguments        = {}
      },
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-processed-dlq"
        destination_type = "queue"
        routing_key      = "video.processed.dlq"
        arguments        = {}
      },
      # ── video-events ──────────────────────────────────────────────────────
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-events"
        destination_type = "queue"
        routing_key      = "video.processed"
        arguments        = {}
      },
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-events"
        destination_type = "queue"
        routing_key      = "video.failed"
        arguments        = {}
      },
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-events-dlq"
        destination_type = "queue"
        routing_key      = "video.events.dlq"
        arguments        = {}
      },
      # ── video-status-uploaded ─────────────────────────────────────────────
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-status-uploaded"
        destination_type = "queue"
        routing_key      = "video.uploaded"
        arguments        = {}
      },
      {
        source           = "video.events"
        vhost            = var.rabbitmq_vhost
        destination      = "video-status-uploaded-dlq"
        destination_type = "queue"
        routing_key      = "video.status.uploaded.dlq"
        arguments        = {}
      }
    ]
  })
}

# Publica as definições iniciais do RabbitMQ como Secret.
resource "kubernetes_secret_v1" "rabbitmq_definitions" {
  metadata {
    name      = "rabbitmq-definitions"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "load_definition.json" = local.rabbitmq_definitions
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# ConfigMap com rabbitmq.conf e enabled_plugins para a imagem oficial.
resource "kubernetes_config_map_v1" "rabbitmq_server_config" {
  metadata {
    name      = "rabbitmq-server-config"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "rabbitmq.conf"   = <<-EOT
      default_vhost = ${var.rabbitmq_vhost}
      default_permissions.configure = .*
      default_permissions.read = .*
      default_permissions.write = .*
      load_definitions = /etc/rabbitmq/definitions/load_definition.json
    EOT
    "enabled_plugins" = "[rabbitmq_management,rabbitmq_prometheus]."
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# StatefulSet RabbitMQ usando a imagem oficial do Docker Hub.
resource "kubernetes_stateful_set_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"     = "rabbitmq"
      "app.kubernetes.io/instance" = "rabbitmq"
    })
  }

  spec {
    service_name = "rabbitmq"
    replicas     = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "rabbitmq"
        "app.kubernetes.io/instance" = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "rabbitmq"
          "app.kubernetes.io/instance" = "rabbitmq"
          "app"                        = "rabbitmq"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "15692"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/scheme" = "http"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.13-management"

          port {
            name           = "amqp"
            container_port = 5672
          }
          port {
            name           = "management"
            container_port = 15672
          }
          port {
            name           = "prometheus"
            container_port = 15692
          }

          env {
            name = "RABBITMQ_DEFAULT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq_secret.metadata[0].name
                key  = "RABBITMQ_USER"
              }
            }
          }
          env {
            name = "RABBITMQ_DEFAULT_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq_secret.metadata[0].name
                key  = "RABBITMQ_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/rabbitmq/rabbitmq.conf"
            sub_path   = "rabbitmq.conf"
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/rabbitmq/enabled_plugins"
            sub_path   = "enabled_plugins"
          }
          volume_mount {
            name       = "definitions"
            mount_path = "/etc/rabbitmq/definitions"
            read_only  = true
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/rabbitmq"
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.rabbitmq_server_config.metadata[0].name
          }
        }

        volume {
          name = "definitions"
          secret {
            secret_name = kubernetes_secret_v1.rabbitmq_definitions.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
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
    kubernetes_secret_v1.rabbitmq_secret,
    kubernetes_secret_v1.rabbitmq_definitions,
    kubernetes_config_map_v1.rabbitmq_server_config,
  ]
}

# Serviço ClusterIP para AMQP (5672) e management (15672) — consumido pelos microservices.
resource "kubernetes_service_v1" "rabbitmq_amqp" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "rabbitmq"
    })
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/instance" = "rabbitmq"
      "app.kubernetes.io/name"     = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
      protocol    = "TCP"
    }
    port {
      name        = "management"
      port        = 15672
      target_port = 15672
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_stateful_set_v1.rabbitmq]
}

# Expõe a interface de administração do RabbitMQ localmente via localhost:15672.
resource "kubernetes_service_v1" "rabbitmq_management" {
  metadata {
    name      = "rabbitmq-management"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = "rabbitmq"
      }
    )
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/instance" = "rabbitmq"
      "app.kubernetes.io/name"     = "rabbitmq"
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_stateful_set_v1.rabbitmq]
}

