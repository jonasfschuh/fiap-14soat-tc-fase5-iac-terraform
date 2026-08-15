# Define filas e componentes padrão para o RabbitMQ local.
locals {
  rabbitmq_definitions = jsonencode({
    vhosts = [
      {
        name = var.rabbitmq_vhost
      }
    ]
    queues = [
      {
        name        = "video.upload.requested"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      {
        name        = "video.processing.requested"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      {
        name        = "video.processing.completed"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      {
        name        = "video.status.updated"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      },
      {
        name        = "notification.email.requested"
        vhost       = var.rabbitmq_vhost
        durable     = true
        auto_delete = false
        arguments   = {}
      }
    ]
  })
}

# Publica as definições iniciais do RabbitMQ para criar vhost e filas automaticamente.
resource "kubernetes_config_map_v1" "rabbitmq_definitions" {
  metadata {
    name      = "rabbitmq-definitions"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "load_definition.json" = local.rabbitmq_definitions
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Instala o RabbitMQ via Helm para mensageria compartilhada entre os microservices.
resource "helm_release" "rabbitmq" {
  name             = "rabbitmq"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "rabbitmq"
  namespace        = kubernetes_namespace_v1.fiapx.metadata[0].name
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    file("${path.module}/../helm-values/rabbitmq-values.yaml"),
    yamlencode({
      auth = {
        username     = var.rabbitmq_user
        password     = var.rabbitmq_password
        erlangCookie = "fiapx-erlang-cookie"
      }
      extraConfiguration = <<-EOT
        default_vhost = ${var.rabbitmq_vhost}
        default_permissions.configure = .*
        default_permissions.read = .*
        default_permissions.write = .*
      EOT
      loadDefinition = {
        enabled           = true
        existingConfigmap = kubernetes_config_map_v1.rabbitmq_definitions.metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.fiapx,
    kubernetes_secret_v1.rabbitmq_secret,
    kubernetes_config_map_v1.rabbitmq_definitions
  ]
}

# Expõe apenas a interface de administração do RabbitMQ localmente via localhost:15672.
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

  depends_on = [helm_release.rabbitmq]
}
