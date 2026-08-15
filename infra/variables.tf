# Declara as variáveis de entrada utilizadas pela infraestrutura local.
variable "kube_context" {
  description = "Contexto do kubeconfig utilizado para provisionar o cluster local."
  type        = string
  default     = "docker-desktop"
}

variable "namespace" {
  description = "Namespace Kubernetes onde a infraestrutura compartilhada será criada."
  type        = string
  default     = "fiapx"
}

variable "rabbitmq_user" {
  description = "Usuário padrão do RabbitMQ."
  type        = string
  default     = "fiapx"
}

variable "rabbitmq_password" {
  description = "Senha padrão do RabbitMQ."
  type        = string
  sensitive   = true
  default     = "fiapx123"
}

variable "rabbitmq_vhost" {
  description = "Virtual host padrão do RabbitMQ."
  type        = string
  default     = "fiapx"
}

variable "jwt_secret" {
  description = "Segredo JWT utilizado pelos microservices de autenticação."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Senha padrão aplicada aos bancos PostgreSQL locais."
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "video_storage_host_path" {
  description = "Diretório local montado no nó do Kubernetes para armazenar vídeos."
  type        = string
  default     = "/data/fiapx-videos"
}

variable "environment" {
  description = "Identificador do ambiente provisionado."
  type        = string
  default     = "local"
}

variable "project_name" {
  description = "Nome amigável do projeto utilizado em labels e anotações."
  type        = string
  default     = "FIAP 14SOAT Fase 5 - RACEFORCE"
}
