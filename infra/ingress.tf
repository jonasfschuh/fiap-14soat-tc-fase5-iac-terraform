# Instala o controlador NGINX Ingress apropriado para o cluster local do Docker Desktop.
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = kubernetes_namespace_v1.fiapx.metadata[0].name
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      controller = {
        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = true
        }
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.fiapx]
}

# Publica as rotas HTTP locais que serão consumidas pelos microservices da aplicação.
resource "kubernetes_ingress_v1" "fiapx" {
  metadata {
    name      = "fiapx-ingress"
    namespace = kubernetes_namespace_v1.fiapx.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        path {
          path      = "/auth(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "auth-service"
              port {
                number = 8090
              }
            }
          }
        }

        path {
          path      = "/upload(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "video-upload-service"
              port {
                number = 8083
              }
            }
          }
        }
        path {
          path      = "/processing(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "video-processing-service"
              port {
                number = 8086
              }
            }
          }
        }

        path {
          path      = "/status(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "video-status-service"
              port {
                number = 8084
              }
            }
          }
        }

        path {
          path      = "/download(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "video-download-service"
              port {
                number = 8085
              }
            }
          }
        }

        path {
          path      = "/notify(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "notification-service"
              port {
                number = 8087
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx]
}
