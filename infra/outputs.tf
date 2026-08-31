# Expõe URLs úteis para acesso local rápido após o provisionamento.
output "mailhog_ui_url" {
  description = "URL local da interface web do MailHog para visualização dos e-mails de teste."
  value       = "http://localhost:8025"
}

output "mailhog_smtp_local" {
  description = "Endereço SMTP do MailHog acessível em desenvolvimento local (fora do cluster)."
  value       = "localhost:1025"
}

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

output "rabbitmq_amqp_local" {
  description = "Endereço AMQP do RabbitMQ acessível em desenvolvimento local."
  value       = "localhost:5672"
}

output "postgres_upload_local" {
  description = "Endereço do banco video_upload_db acessível em desenvolvimento local."
  value       = "localhost:5433"
}

output "postgres_status_local" {
  description = "Endereço do banco video_status_db acessível em desenvolvimento local."
  value       = "localhost:5434"
}

output "postgres_processing_local" {
  description = "Endereço do banco video_processing_db acessível em desenvolvimento local."
  value       = "localhost:5435"
}

output "postgres_auth_local" {
  description = "Endereço do banco auth_db acessível em desenvolvimento local."
  value       = "localhost:5430"
}
