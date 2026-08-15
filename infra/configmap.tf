# Expõe parâmetros compartilhados de mensageria e integração interna entre serviços.
resource "kubernetes_config_map_v1" "rabbitmq_config" {
  metadata {
    name      = "rabbitmq-config"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    RABBITMQ_HOST    = "rabbitmq.${var.namespace}.svc.cluster.local"
    RABBITMQ_PORT    = "5672"
    RABBITMQ_VHOST   = var.rabbitmq_vhost
    AUTH_SERVICE_URL = "http://auth-service.${var.namespace}.svc.cluster.local:8090"
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}
