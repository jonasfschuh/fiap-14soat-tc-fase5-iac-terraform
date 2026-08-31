#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_DIR}/infra"
TFVARS_FILE="${INFRA_DIR}/terraform.tfvars"

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[ERRO] Comando obrigatório não encontrado: ${command_name}" >&2
    exit 1
  fi
}

echo "[INFO] Validando pré-requisitos locais..."
require_command docker
require_command kubectl
require_command helm
require_command terraform

if ! docker info >/dev/null 2>&1; then
  echo "[ERRO] Docker Desktop não está em execução ou o daemon Docker não respondeu." >&2
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [[ "${CURRENT_CONTEXT}" != "docker-desktop" ]]; then
  echo "[ERRO] O contexto atual do kubectl deve ser 'docker-desktop'. Contexto atual: '${CURRENT_CONTEXT}'." >&2
  exit 1
fi

if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "[ERRO] Arquivo ${TFVARS_FILE} não encontrado. Copie terraform.tfvars.example e ajuste os valores." >&2
  exit 1
fi

if grep -q 'TROQUE-POR-UMA-CHAVE-FORTE' "${TFVARS_FILE}"; then
  echo "[ERRO] Atualize o valor de jwt_secret em infra/terraform.tfvars antes de aplicar a infraestrutura." >&2
  exit 1
fi

echo "[INFO] Preparando diretório compartilhado de vídeos em /data/fiapx-videos..."
MSYS_NO_PATHCONV=1 docker run --rm -v /data/fiapx-videos:/target alpine:3.20 sh -c 'mkdir -p /target/uploads /target/processed'

echo "[INFO] Inicializando providers Terraform..."
terraform -chdir="${INFRA_DIR}" init -input=false

echo "[INFO] Aplicando infraestrutura local no namespace fiapx..."
terraform -chdir="${INFRA_DIR}" apply -input=false -auto-approve

echo
echo "[OK] Infraestrutura local provisionada com sucesso."
echo "- MailHog UI:  http://localhost:8025 (caixa de entrada de e-mails de teste)"
echo "- MailHog SMTP: localhost:1025 (para conexão de aplicações locais)"
echo "- RabbitMQ Management: http://localhost:15672 (usuário: fiapx, senha: fiapx123, VHost: fiapx)"
echo "- RabbitMQ AMQP:   localhost:5672 (para conexão dos microservices)"
echo "- PostgreSQL auth:       localhost:5430 (banco: auth_db)"
echo "- PostgreSQL upload:     localhost:5433 (banco: video_upload_db)"
echo "- PostgreSQL status:     localhost:5434 (banco: video_status_db)"
echo "- PostgreSQL processing: localhost:5435 (banco: video_processing_db)"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana:    http://localhost:3000"
echo "- Ingress:    http://localhost"
echo "- Storage:    /data/fiapx-videos"
