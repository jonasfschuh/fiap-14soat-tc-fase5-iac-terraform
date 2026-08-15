# Expõe URLs úteis para acesso local rápido após o provisionamento.
output "rabbitmq_management_url" {
  description = "URL local da interface de administração do RabbitMQ."
  value       = "http://localhost:15672"
}

output "grafana_url" {
  description = "URL local do Grafana."
  value       = "http://localhost:3000"
}

output "prometheus_url" {
  description = "URL local do Prometheus."
  value       = "http://localhost:9090"
}

output "ingress_url" {
  description = "URL base do Ingress local do NGINX."
  value       = "http://localhost"
}

output "video_storage_path" {
  description = "Diretório local usado para persistir vídeos no cluster."
  value       = var.video_storage_host_path
}
