# Mapeia os bancos PostgreSQL compartilhados usados pelos microservices locais.
locals {
  postgres_databases = {
    auth = {
      service_name = "postgres-auth"
      secret_name  = "postgres-auth-secret"
      db_name      = "auth_db"
    }
    upload = {
      service_name = "postgres-upload"
      secret_name  = "postgres-upload-secret"
      db_name      = "video_upload_db"
    }
    processing = {
      service_name = "postgres-processing"
      secret_name  = "postgres-processing-secret"
      db_name      = "video_processing_db"
    }
    status = {
      service_name = "postgres-status"
      secret_name  = "postgres-status-secret"
      db_name      = "video_status_db"
    }
  }
}

# Publica o segredo JWT consumido pelos microservices da solução.
resource "kubernetes_secret_v1" "jwt_secret" {
  metadata {
    name      = "jwt-secret"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    JWT_SECRET = var.jwt_secret
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Publica as credenciais compartilhadas do RabbitMQ.
resource "kubernetes_secret_v1" "rabbitmq_secret" {
  metadata {
    name      = "rabbitmq-secret"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    RABBITMQ_USER     = var.rabbitmq_user
    RABBITMQ_PASSWORD = var.rabbitmq_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Publica as credenciais dos bancos PostgreSQL por microservice.
resource "kubernetes_secret_v1" "postgres_secret" {
  for_each = local.postgres_databases

  metadata {
    name      = each.value.secret_name
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/name" = each.value.service_name
      }
    )
  }

  data = {
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = each.value.db_name

    # Chaves no formato Spring Boot para consumo direto pelos microservices
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${each.value.service_name}:5432/${each.value.db_name}"
    SPRING_DATASOURCE_USERNAME = "postgres"
    SPRING_DATASOURCE_PASSWORD = var.postgres_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.fiapx]
}
