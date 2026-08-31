# Expõe os recursos compartilhados para acesso direto em desenvolvimento local.
#
# Portas disponíveis no localhost após o provisionamento:
#   RabbitMQ AMQP  : localhost:5672
#   PostgreSQL auth      : localhost:5430
#   PostgreSQL upload    : localhost:5433
#   PostgreSQL status    : localhost:5434
#   PostgreSQL processing: localhost:5435

locals {
  # Porta host que cada banco expõe em localhost via LoadBalancer.
  postgres_lb_host_ports = {
    auth       = 5430
    upload     = 5433
    status     = 5434
    processing = 5435
  }
}

# ─── RabbitMQ AMQP externo ───────────────────────────────────────────────────
# Expõe a porta AMQP do RabbitMQ em localhost:5672 para que os microservices
# em desenvolvimento local (IntelliJ) e containers Docker consigam conectar.
resource "kubernetes_service_v1" "rabbitmq_amqp_lb" {
  metadata {
    name      = "rabbitmq-amqp-lb"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "rabbitmq"
    })
  }

  spec {
    type = "LoadBalancer"

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
  }

  depends_on = [kubernetes_stateful_set_v1.rabbitmq]
}

# ─── PostgreSQL — LoadBalancer por microservice ───────────────────────────────
# Cada banco recebe um serviço LoadBalancer em uma porta local distinta para
# que a aplicação rodando na IDE ou via Docker Compose consiga conectar
# sem conflito de portas.
resource "kubernetes_service_v1" "postgres_lb" {
  for_each = local.postgres_databases

  metadata {
    name      = "${each.value.service_name}-lb"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = each.value.service_name
      }
    )
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = each.value.service_name
    }

    port {
      name        = "postgres"
      port        = local.postgres_lb_host_ports[each.key]
      target_port = 5432
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_stateful_set_v1.postgres]
}
