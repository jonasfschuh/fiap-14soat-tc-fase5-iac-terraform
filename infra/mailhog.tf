# MailHog — SMTP mock para desenvolvimento/teste de envio de e-mails.
# Expõe a porta SMTP (1025) internamente no cluster e a UI (8025) via LoadBalancer.

resource "kubernetes_deployment_v1" "mailhog" {
  metadata {
    name      = "mailhog"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"     = "mailhog"
      "app.kubernetes.io/instance" = "mailhog"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mailhog"
        "app.kubernetes.io/instance" = "mailhog"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "mailhog"
          "app.kubernetes.io/instance" = "mailhog"
          "app"                        = "mailhog"
        }
      }

      spec {
        container {
          name  = "mailhog"
          image = "mailhog/mailhog:latest"

          port {
            name           = "smtp"
            container_port = 1025
          }
          port {
            name           = "http"
            container_port = 8025
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8025
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8025
            }
            initial_delay_seconds = 15
            period_seconds        = 30
            timeout_seconds       = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# ClusterIP — acessível internamente pelos microserviços via SMTP (1025) e HTTP (8025).
resource "kubernetes_service_v1" "mailhog" {
  metadata {
    name      = "mailhog"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "mailhog"
    })
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name"     = "mailhog"
      "app.kubernetes.io/instance" = "mailhog"
    }

    port {
      name        = "smtp"
      port        = 1025
      target_port = 1025
      protocol    = "TCP"
    }

    port {
      name        = "http"
      port        = 8025
      target_port = 8025
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment_v1.mailhog]
}

# LoadBalancer — expõe a UI web do MailHog em localhost:8025 para inspeção local.
resource "kubernetes_service_v1" "mailhog_lb" {
  metadata {
    name      = "mailhog-lb"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "mailhog"
    })
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name"     = "mailhog"
      "app.kubernetes.io/instance" = "mailhog"
    }

    port {
      name        = "smtp"
      port        = 1025
      target_port = 1025
      protocol    = "TCP"
    }

    port {
      name        = "http"
      port        = 8025
      target_port = 8025
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment_v1.mailhog]
}
