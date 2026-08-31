# fiap-14soat-tc-fase5-iac-terraform

![Terraform](https://img.shields.io/badge/Terraform_%7E1.5-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm_3-%230F1689.svg?style=for-the-badge&logo=helm&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL_16-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-%23FF6600.svg?style=for-the-badge&logo=rabbitmq&logoColor=white)
![MailHog](https://img.shields.io/badge/MailHog-SMTP_Mock-%238B4513.svg?style=for-the-badge&logo=mail.ru&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-%23E6522C.svg?style=for-the-badge&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX_Ingress-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)
![Infrastructure as Code](https://img.shields.io/badge/Infrastructure_as_Code-IaC-5C4EE5?style=for-the-badge)

---

## 📑 Sumário

- [👤 Autor](#-autor)
- [📋 Descrição](#-descrição)
- [🏗️ Arquitetura](#️-arquitetura)
- [🛠️ Tecnologias Utilizadas](#️-tecnologias-utilizadas)
- [🔒 Proteção da Branch main](#-proteção-da-branch-main)
- [🚀 Provisionamento Local](#-provisionamento-local)
- [⚙️ Variáveis de Configuração](#️-variáveis-de-configuração)
- [🤖 CI/CD — Self-Hosted Runner](#-cicd--self-hosted-runner)
- [🎬 Vídeos de Apresentação](#-vídeos-de-apresentação)
- [🔗 Repositórios Relacionados](#-repositórios-relacionados)

---

## 👤 Autor

| Nome                 | E-mail                  | RM        | Discord          | WhatsApp        |
|----------------------|-------------------------|-----------|------------------|-----------------|
| Jonas Fernando Schuh | jonasschuh@hotmail.com  | rm369458  | jonasf.schuh     | 47 9 9960-1396  |

**Grupo:** 2 · FIAP 14SOAT Fase 5 — RaceForce

---

## 📋 Descrição

Este repositório contém a **infraestrutura local em Terraform** para o ecossistema de processamento de vídeos da FIAP 14SOAT Fase 5, utilizando **Kubernetes no Docker Desktop**.

### O que este repositório provisiona

| Componente | Descrição |
|------------|-----------|
| **Namespace `fiapx`** | Namespace Kubernetes dedicado ao ecossistema |
| **RabbitMQ** | Message broker compartilhado com UI de gerenciamento local |
| **PostgreSQL (×4)** | Bancos de dados dedicados: `auth`, `upload`, `processing` e `status` |
| **MailHog** | SMTP mock para captura e inspeção de e-mails de teste |
| **Volume persistente** | Armazenamento local para vídeos |
| **NGINX Ingress Controller** | Roteamento de requisições HTTP para os microserviços |
| **Prometheus + Grafana** | Stack de observabilidade e monitoramento |
| **Secrets e ConfigMaps** | Configurações compartilhadas pelos microserviços |

> ℹ️ Os microserviços **não** são implantados aqui. Este repositório provisiona apenas a **infraestrutura compartilhada** para execução local.

### Microserviços esperados

| Serviço | Porta |
|---------|-------|
| `auth-service` | `8090` |
| `video-upload-service` | `8083` |
| `video-processing-service` | `8086` |
| `video-status-service` | `8084` |
| `video-download-service` | `8085` |
| `notification-service` | `8087` |

---

## 🏗️ Arquitetura

### Infraestrutura provisionada

```text
┌─────────────────────────────────────────────────────────────────┐
│                  Kubernetes (Docker Desktop)                     │
│                    Namespace: fiapx                              │
│                                                                  │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐ │
│  │ NGINX Ingress│  │              PostgreSQL (×4)              │ │
│  │  Controller  │  │  auth | upload | processing | status      │ │
│  └──────┬───────┘  └──────────────────────────────────────────┘ │
│         │                                                        │
│  ┌──────▼────────────────────────────────────────────────────┐  │
│  │                     RabbitMQ                               │  │
│  │           AMQP :5672  |  Management UI :15672              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐  │
│  │      Prometheus      │  │            Grafana               │  │
│  │        :9090         │  │             :3000                │  │
│  └─────────────────────┘  └──────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                     MailHog                              │    │
│  │   SMTP :1025 (interno + localhost)  |  Web UI :8025      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Volume persistente: /data/fiapx-videos             │  │
│  │            uploads/   |   processed/                       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Rotas do Ingress

| Rota | Destino |
|------|---------|
| `http://localhost/auth` | auth-service |
| `http://localhost/upload` | video-upload-service |
| `http://localhost/status` | video-status-service |
| `http://localhost/download` | video-download-service |
| `http://localhost/notify` | notification-service |

### Estrutura de diretórios

```text
infra/         → Terraform da infraestrutura local
helm-values/   → Values dos charts Helm
scripts/       → Scripts utilitários de setup e destroy
```

---

## 🛠️ Tecnologias Utilizadas

| Tecnologia | Versão | Uso |
|------------|--------|-----|
| **Terraform** | ~1.5 | Provisionamento de toda a infraestrutura |
| **Kubernetes** | 1.28+ | Orquestração de containers (Docker Desktop) |
| **Helm** | 3.x | Gerenciamento de charts (RabbitMQ, Prometheus, Grafana) |
| **Docker Desktop** | 4.x+ | Runtime Kubernetes local |
| **PostgreSQL** | 16 | 4 bancos de dados independentes por microserviço |
| **RabbitMQ** | 3.x | Message broker para comunicação assíncrona |
| **MailHog** | latest | SMTP mock para captura de e-mails em ambiente de desenvolvimento |
| **Prometheus** | Latest | Coleta de métricas dos microserviços |
| **Grafana** | Latest | Dashboards de observabilidade |
| **NGINX Ingress** | Latest | Controller de roteamento HTTP |
| **GitHub Actions** | — | CI/CD com self-hosted runner local |

---

## 🔒 Proteção da Branch main

As regras abaixo seguem o padrão dos demais repositórios da stack:

| Regra | Valor |
|---|---|
| **Require a pull request before merging** | ✅ Ativado |
| **Required approvals** | `1` aprovação |
| **Dismiss stale reviews on new commits** | ✅ Ativado |
| **Require status checks to pass** | ✅ Ativado |
| **Require branches to be up to date** | ✅ Ativado |
| **Do not allow bypassing** | ✅ Ativado |

### Status checks obrigatórios

| Check | Job |
|---|---|
| `terraform-validate` | `terraform init` + `terraform validate` na pasta `infra/` |

---

## 🚀 Provisionamento Local

### Pré-requisitos

- Docker Desktop com Kubernetes habilitado
- `kubectl`
- `helm`
- `terraform`
- Shell Bash compatível (`Git Bash`, `WSL` ou similar)

Valide o contexto ativo:

```bash
kubectl config current-context
# saída esperada: docker-desktop
```

### Configuração do `terraform.tfvars`

1. Entre na pasta `infra/`.
2. Copie o arquivo de exemplo:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Ajuste principalmente o `jwt_secret` com uma chave forte de no mínimo 32 caracteres:

```hcl
kube_context            = "docker-desktop"
namespace               = "fiapx"
rabbitmq_user           = "fiapx"
rabbitmq_password       = "fiapx123"
rabbitmq_vhost          = "fiapx"
jwt_secret              = "TROQUE-POR-UMA-CHAVE-FORTE-DE-32-CHARS-MINIMO"
postgres_password       = "postgres"
video_storage_host_path = "/data/fiapx-videos"
```

### Provisionando o ambiente

Execute a partir da raiz do repositório:

```bash
bash scripts/setup-cluster.sh
```

O script executa automaticamente:

1. Validação do Docker Desktop;
2. Validação do contexto `docker-desktop` no `kubectl`;
3. Criação dos diretórios `/data/fiapx-videos/uploads` e `/data/fiapx-videos/processed`;
4. `terraform init` na pasta `infra/`;
5. `terraform apply -auto-approve`.

### URLs de acesso após o setup

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **RabbitMQ Management** | http://localhost:15672 | Interface de gerenciamento do broker |
| **MailHog UI** | http://localhost:8025 | Caixa de entrada dos e-mails de teste |
| **MailHog SMTP** | localhost:1025 | SMTP acessível para aplicações locais (IDE, docker-compose) |
| **Prometheus** | http://localhost:9090 | Métricas e alertas |
| **Grafana** | http://localhost:3000 | Dashboards de observabilidade |
| **Ingress base** | http://localhost | Entrada principal dos microserviços |

### Destruição do ambiente

Para remover toda a infraestrutura local provisionada:

```bash
bash scripts/destroy.sh
```

> 💡 **Observação:** O Docker Desktop expõe serviços `LoadBalancer` diretamente em `localhost`. Por isso, os componentes que precisam responder nas portas `15672`, `9090` e `3000` usam esse modo em vez de `NodePort`, já que o Kubernetes padrão não permite `NodePort` abaixo de `30000`.

---

## ⚙️ Variáveis de Configuração

| Variável | Exemplo | Descrição |
|----------|---------|-----------|
| `kube_context` | `docker-desktop` | Contexto Kubernetes ativo |
| `namespace` | `fiapx` | Namespace do ecossistema |
| `rabbitmq_user` | `fiapx` | Usuário do RabbitMQ |
| `rabbitmq_password` | `fiapx123` | Senha do RabbitMQ |
| `rabbitmq_vhost` | `fiapx` | Virtual host do RabbitMQ |
| `jwt_secret` | `CHAVE-FORTE-32-CHARS` | Segredo JWT (mín. 32 caracteres) |
| `postgres_password` | `postgres` | Senha padrão do PostgreSQL |
| `video_storage_host_path` | `/data/fiapx-videos` | Caminho do volume persistente de vídeos |

> 💡 **MailHog** não requer variáveis de configuração — é provisionado com a imagem `mailhog/mailhog:latest` e expõe automaticamente SMTP na porta `1025` (interno) e UI na porta `8025` (localhost).

---

## 🤖 CI/CD — Self-Hosted Runner

O pipeline de deploy deste repositório utiliza um **GitHub Actions self-hosted runner** rodando na máquina local com acesso ao cluster Kubernetes (Docker Desktop).

### Pré-requisitos do runner

| Ferramenta | Versão mínima | Verificar |
|-----------|---------------|-----------|
| Docker Desktop (com K8s habilitado) | 4.x+ | `docker version` |
| kubectl | 1.28+ | `kubectl version --client` |
| Terraform | 1.5+ | `terraform version` |
| Helm | 3.x+ | `helm version` |

### Passo a passo — configurar o runner

#### 1. Acesse as configurações do repositório no GitHub

```
GitHub → Repositório → Settings → Actions → Runners → New self-hosted runner
```

#### 2. Escolha o sistema operacional

Selecione **Windows** e a arquitetura **x64**.

#### 3. Baixe e configure o runner

Execute os comandos exibidos pelo GitHub na sua máquina local (PowerShell como Administrador):

```powershell
# Criar pasta para o runner
mkdir C:\actions-runner; cd C:\actions-runner

# Baixar o runner (substitua a URL pela exibida no GitHub)
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/vX.X.X/actions-runner-win-x64-X.X.X.zip -OutFile actions-runner.zip

# Extrair
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner.zip", "$PWD")

# Configurar (use o token gerado pelo GitHub na tela de configuração)
.\config.cmd --url https://github.com/<org>/<repo> --token <TOKEN-GERADO-PELO-GITHUB>
```

#### 4. Instalar como serviço Windows (recomendado)

```powershell
# Instalar e iniciar como serviço Windows (executa automaticamente no boot)
.\svc.cmd install
.\svc.cmd start

# Verificar status
.\svc.cmd status
```

#### 5. Verificar o runner no GitHub

```
GitHub → Repositório → Settings → Actions → Runners
```

O runner deve aparecer com status **Idle** (verde). A partir daí, qualquer push para `main` disparará o pipeline de deploy automaticamente.

### Verificar o deploy após o pipeline

```powershell
# Listar pods no namespace fiapx
kubectl get pods -n fiapx

# Verificar logs de um serviço
kubectl logs -l app=<nome-do-app> -n fiapx --tail=50

# Acessar via Ingress (após NGINX estar ativo)
# http://localhost/<caminho>
```

### Gerenciar o runner

```powershell
# Parar o serviço
.\svc.cmd stop

# Remover o serviço
.\svc.cmd uninstall

# Remover o runner do GitHub
.\config.cmd remove --token <TOKEN>
```

> 💡 **Dica:** Para múltiplos repositórios, crie uma pasta separada para cada runner (ex: `C:\actions-runner\iac`, `C:\actions-runner\upload`) e repita o processo para cada um.

---

## 🎬 Vídeos de Apresentação

| Fase | Link |
|------|------|
| Fase 1 | [Apresentação Tech Challenge 1 — RaceForce](https://youtu.be/EKwE8l4yE1M) |
| Fase 2 | [Apresentação Tech Challenge 2 — RaceForce](https://youtu.be/95ml0-H9Vf4) |
| Fase 3 | [Apresentação Tech Challenge 3 — RaceForce](https://www.youtube.com/watch?v=KB-FC_4zsPE) |
| Fase 4 | [Apresentação Tech Challenge 4 — RaceForce](https://www.youtube.com/watch?v=vR3x4kW0l90) |
| Fase 5 | *(em desenvolvimento)* |

---

## 🔗 Repositórios Relacionados

| Ordem | Repositório | Descrição |
|-------|-------------|-----------|
| 1 | [fiap-14soat-tc-fase5-iac-terraform](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-iac-terraform) | Banco de dados, RabbitMQ — infraestrutura AWS |
| 2 | [fiap-14soat-tc-fase5-auth](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-auth) | Login Authorizer            |
| 3 | [fiap-14soat-tc-fase5-video-upload-service](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-video-upload-service) | Upload + RabbitMQ publisher |
| 4 | [fiap-14soat-tc-fase5-video-processing-service](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-video-processing-service) | Processa vídeo, extrai frames, gera ZIP |
| 5 | [fiap-14soat-tc-fase5-video-status-service](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-video-status-service) | Status e metadados dos vídeos por usuário |
| 6 | [fiap-14soat-tc-fase5-video-download-service](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-video-download-service) | Download do ZIP via presigned URL |
| 7 | [fiap-14soat-tc-fase5-notification-service](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-notification-service) | Notificação por e-mail em caso de erro/conclusão |
| 8 | [fiap-14soat-tc-fase5-observability](https://github.com/jonasfschuh/fiap-14soat-tc-fase5-observability) | Prometheus + Grafana — dashboards e alertas |

---

<div align="center">

**🎓 Desenvolvido para o Tech Challenge FIAP 14SOAT — Fase 5**

*Projeto Acadêmico — Pós-Graduação em Arquitetura de Software · FIAP 2025/2026*

[⬆ Voltar ao topo](#fiap-14soat-tc-fase5-iac-terraform)

</div>
