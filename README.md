# fiap-14soat-tc-fase5-iac-terraform

Infraestrutura local em Terraform para o ecossistema de processamento de vídeos da FIAP 14SOAT Fase 5, usando Kubernetes no Docker Desktop.

## O que este repositório provisiona

- Namespace `fiapx`
- RabbitMQ compartilhado com UI local
- 4 bancos PostgreSQL dedicados (`auth`, `upload`, `processing`, `status`)
- Volume persistente local para vídeos
- NGINX Ingress Controller
- Prometheus e Grafana
- Secrets e ConfigMaps compartilhados pelos microservices

> Os microservices **não** são implantados aqui. Este repositório provisiona apenas a infraestrutura compartilhada para execução local.

## Microservices esperados

- `auth-service` — porta `8090`
- `video-upload-service` — porta `8083`
- `video-processing-service` — porta `8086`
- `video-status-service` — porta `8084`
- `video-download-service` — porta `8085`
- `notification-service` — porta `8087`

## Pré-requisitos

Instale e configure localmente:

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

## Configuração do `terraform.tfvars`

1. Entre na pasta `infra/`.
2. Copie o arquivo de exemplo:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Ajuste principalmente o `jwt_secret` com uma chave forte de no mínimo 32 caracteres.

Exemplo:

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

## Provisionando o ambiente local

Execute a partir da raiz do repositório:

```bash
bash scripts/setup-cluster.sh
```

O script faz automaticamente:

1. validação do Docker Desktop;
2. validação do contexto `docker-desktop` no `kubectl`;
3. criação dos diretórios `/data/fiapx-videos/uploads` e `/data/fiapx-videos/processed`;
4. `terraform init` na pasta `infra/`;
5. `terraform apply -auto-approve`.

## URLs de acesso após o setup

- RabbitMQ Management: `http://localhost:15672`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- Ingress base: `http://localhost`

Rotas esperadas no Ingress:

- `http://localhost/auth`
- `http://localhost/upload`
- `http://localhost/status`
- `http://localhost/download`
- `http://localhost/notify`

## Observação sobre exposição local

O Docker Desktop expõe serviços `LoadBalancer` diretamente em `localhost`. Por isso, os componentes que precisam responder nas portas `15672`, `9090` e `3000` usam esse modo em vez de `NodePort`, já que o Kubernetes padrão não permite `NodePort` abaixo de `30000`.

## Destruição do ambiente

Para remover toda a infraestrutura local provisionada:

```bash
bash scripts/destroy.sh
```

## Estrutura principal

```text
infra/         Terraform da infraestrutura local
helm-values/   Values dos charts Helm
scripts/       Scripts utilitários de setup e destroy
```

---

## ⚙️ CI/CD — Configurando o Self-Hosted Runner

O pipeline de deploy deste repositório utiliza um **GitHub Actions self-hosted runner** rodando na máquina local com acesso ao cluster Kubernetes (Docker Desktop).

### Pré-requisitos do runner

Certifique-se de que a máquina possui instalado:

| Ferramenta | Versão mínima | Verificar |
|-----------|---------------|-----------|
| Docker Desktop (com K8s habilitado) | 4.x+ | `docker version` |
| kubectl | 1.28+ | `kubectl version --client` |
| Java 21 (JDK) | 21+ | `java -version` |
| Maven Wrapper | — | `.\mvnw.cmd -version` |

> Para o repositório IAC, também é necessário `terraform` (1.5+) e `helm` (3.x+).

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
# Criar pasta para o runner (ajuste o caminho se necessário)
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

O runner deve aparecer com status **Idle** (verde). A partir daí, qualquer push para `main` ou `develop` disparará o pipeline de deploy automaticamente.

### Verificar o deploy após o pipeline

```powershell
# Listar pods no namespace fiapx
kubectl get pods -n fiapx

# Verificar logs do serviço
kubectl logs -l app=<nome-do-app> -n fiapx --tail=50

# Acessar via Swagger (após NGINX Ingress estar ativo)
# http://localhost/<caminho>/swagger-ui.html
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

> 💡 **Dica:** Para múltiplos repositórios, crie uma pasta separada para cada runner (ex: `C:\actions-runner\auth`, `C:\actions-runner\upload`) e repita o processo para cada um.
