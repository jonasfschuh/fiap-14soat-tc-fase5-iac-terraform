#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_DIR}/infra"

if ! command -v terraform >/dev/null 2>&1; then
  echo "[ERRO] Terraform não encontrado no PATH." >&2
  exit 1
fi

echo "[INFO] Inicializando providers Terraform..."
terraform -chdir="${INFRA_DIR}" init -input=false

echo "[INFO] Destruindo a infraestrutura local do namespace fiapx..."
terraform -chdir="${INFRA_DIR}" destroy -input=false -auto-approve

echo "[OK] Infraestrutura local destruída com sucesso."
