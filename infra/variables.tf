# Obrigatórias
variable "bucket_name" {
  description = "O nome único para o bucket S3. Deve ser globalmente único."
  type        = string
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS. Exemplo: eks-cluster-fiap-14soat-fase4-raceforce"
  type        = string
}

# Opcionais
variable "aws_region" {
  description = "A região da AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "O ambiente ao qual o recurso pertence (ex: Dev, Staging, Prod)."
  type        = string
  default     = "Dev"
}

variable "project_name" {
  description = "Nome do projeto para ser usado em tags."
  type        = string
  default     = "FIAP 14SOAT Fase 4 - RACEFORCE"
}

variable "project_identifier" {
  description = "Identificador único do projeto para ser usado em tags."
  type        = string
  default     = "fiap-14soat-fase4-raceforce"
}

variable "eks_cluster_role_name" {
  description = "Nome da role IAM pre-provisionada para o controle do EKS no Learner Lab."
  type        = string
  default     = "LabRole"
}

variable "eks_node_role_name" {
  description = "Nome da role IAM pre-provisionada para os nodes do EKS no Learner Lab."
  type        = string
  default     = "LabRole"
}

variable "eks_supported_control_plane_azs" {
  description = "AZs elegiveis para o control plane do EKS no us-east-1."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
}

variable "eks_node_instance_types" {
  description = "Lista de tipos de instância para os nós do EKS."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_disk_size" {
  description = "Tamanho do disco em GB a ser anexado a cada nó do EKS."
  type        = number
  default     = 20
}

variable "eks_node_scaling_desired_size" {
  description = "Número desejado de nós no grupo do EKS."
  type        = number
  default     = 2
}

variable "eks_node_scaling_max_size" {
  description = "Número máximo de nós no grupo do EKS."
  type        = number
  default     = 2
}

# Variáveis para API Gateway e Lambda
variable "lambda_terraform_state_bucket" {
  description = "Nome do bucket S3 onde está o tfstate da Lambda"
  type        = string
  default     = "fiap-14soat-fase4-jonasfschuh"
}

variable "lambda_terraform_state_key" {
  description = "Chave do tfstate da Lambda no bucket S3"
  type        = string
  default     = "lambda-auth/terraform.tfstate"
}

variable "jwt_issuer" {
  description = "Emissor do token JWT (deve ser igual ao configurado na Lambda)"
  type        = string
  default     = "RaceforceApi"
}

variable "jwt_audience" {
  description = "Audiência do token JWT (deve ser igual ao configurado na Lambda)"
  type        = string
  default     = "AuthorizedServices"
}

variable "eks_node_scaling_min_size" {
  description = "Número mínimo de nós no grupo do EKS."
  type        = number
  default     = 1
}

variable "enable_new_relic" {
  description = "Habilita a instalacao do chart New Relic no cluster."
  type        = bool
  default     = false
}

variable "new_relic_license_key" {
  description = "Chave de licença do New Relic para monitoramento do cluster"
  type        = string
  sensitive   = true
  default     = ""
}

variable "new_relic_namespace" {
  description = "Namespace Kubernetes onde o bundle do New Relic sera instalado"
  type        = string
  default     = "newrelic"
}

variable "new_relic_cluster_name_override" {
  description = "Override opcional para o nome do cluster exibido no New Relic"
  type        = string
  default     = ""
}

variable "new_relic_helm_timeout_seconds" {
  description = "Timeout em segundos para instalacao/upgrade do chart nri-bundle"
  type        = number
  default     = 900
}

variable "new_relic_helm_wait" {
  description = "Define se o Helm deve aguardar recursos ficarem prontos"
  type        = bool
  default     = true
}

variable "new_relic_helm_wait_for_jobs" {
  description = "Define se o Helm deve aguardar jobs do chart concluirem"
  type        = bool
  default     = false
}

variable "new_relic_helm_atomic" {
  description = "Executa rollback automatico do release em caso de falha"
  type        = bool
  default     = false
}

variable "new_relic_helm_cleanup_on_fail" {
  description = "Remove recursos criados parcialmente quando o release falha"
  type        = bool
  default     = false
}

variable "enable_eks_ci_access_entry" {
  description = "Habilita a criacao de access entry para o principal que executa o Terraform (necessario para Helm/Kubernetes provider no CI)."
  type        = bool
  default     = true
}

variable "eks_ci_access_principal_arn" {
  description = "ARN opcional do principal IAM que deve receber acesso admin no EKS. Se vazio, usa o caller atual (com conversao STS assumed-role -> IAM role)."
  type        = string
  default     = ""
}

# =============================================================================
# RDS PostgreSQL Compartilhado
# =============================================================================

variable "rds_identifier" {
  description = "Identificador da instancia RDS compartilhada"
  type        = string
  default     = "raceforce-shared-postgres"
}

variable "rds_engine_version" {
  description = "Versao do engine PostgreSQL"
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "Classe da instancia RDS — db.t3.micro para custo minimo"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_master_username" {
  description = "Username master do banco de dados compartilhado"
  type        = string
  default     = "postgres"
}

variable "rds_master_password" {
  description = "Senha master do banco de dados compartilhado"
  type        = string
  sensitive   = true
}


