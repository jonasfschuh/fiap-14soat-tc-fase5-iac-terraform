# RFC-003 — Infraestrutura Kubernetes Local (Docker Desktop) com Terraform

| Campo        | Valor                                                   |
|--------------|-----------------------------------------------------------|
| **RFC**      | 003                                                     |
| **Título**   | Provisionamento de um cluster Kubernetes local via Terraform (sem AWS) |
| **Repositório** | fiap-14soat-tc-fase5-iac-terraform                      |
| **Status**   | Aceito — **revisado em 2026-09-10** (substitui a versão anterior baseada em EKS/VPC/AWS) |
| **Autor**    | Time FIAP 14SOAT Fase 5                                |
| **Data**     | 2026-04-20 (criado) · 2026-07-17 (revisado — SQS/RDS/SNS) · 2026-09-10 (revisado — remoção total de AWS) |

---

## ⚠️ Nota sobre a revisão

A versão original deste RFC descrevia provisionamento de **VPC, subnets públicas, EKS e New Relic via Helm na AWS**. Essa arquitetura **não corresponde mais ao projeto**: não há VPC, conta AWS ou cluster EKS envolvidos. O `infra/provider.tf` usa exclusivamente o **kubeconfig local**, apontando para o contexto `docker-desktop` (`var.kube_context`, default `"docker-desktop"`). Esta revisão substitui o conteúdo pela arquitetura efetivamente implementada: um cluster **Kubernetes do Docker Desktop**, provisionado e gerenciado 100% via Terraform.

---

## 1. Resumo

Este documento justifica as escolhas de infraestrutura como código (IaC) para provisionar, em um **cluster Kubernetes local (Docker Desktop)**, todos os recursos compartilhados da plataforma de processamento de vídeos: namespace, RabbitMQ, PostgreSQL (um por microsserviço), Ingress NGINX, MailHog (SMTP mock) e a stack de observabilidade (Prometheus + Grafana + New Relic), utilizando **Terraform** com os providers `kubernetes` e `helm`.

---

## 2. Motivação

O Hackathon (`docs/requirements/POSTECH - SOAT - Fase 5 - Hacka.txt`) exige, na Stack Tecnológica Recomendada:

- **Containers**: Docker + Kubernetes ou Docker Compose;
- **Mensageria**: RabbitMQ, Amazon SQS ou similar;
- **Banco de Dados**: PostgreSQL + Redis (cache) ou outro de preferência do grupo;
- **Monitoramento**: Prometheus + Grafana ou preferência do grupo;
- Arquitetura escalável e persistência de dados.

A equipe optou por atender a esses requisitos **sem depender de uma conta de nuvem** (AWS, GCP ou Azure), utilizando um cluster **Kubernetes local do Docker Desktop**, provisionado de forma reprodutível via Terraform. Essa escolha elimina qualquer dependência de créditos, sessões temporárias ou orçamento de laboratório (ex.: AWS Academy), tornando o ambiente **100% reprodutível na máquina de qualquer membro da equipe** que tenha Docker Desktop com Kubernetes habilitado.

---

## 3. Proposta

### 3.1 Escolha do Ambiente — Kubernetes local via Docker Desktop

| Opção | Prós | Contras | Decisão |
|-------|------|---------|---------|
| **Kubernetes do Docker Desktop** | Gratuito, sem conta de nuvem, reprodutível localmente, já vem integrado ao Docker Desktop | Não reflete 100% um ambiente de produção real (sem HA, sem múltiplos nós) | **Escolhido** |
| Amazon EKS (arquitetura original) | Gerenciado, integração IAM nativa, mais próximo de produção real | Exige conta AWS ativa, créditos, VPC/subnets — indisponível no escopo atual | Rejeitado (revogado) |
| kind / minikube | Também locais e gratuitos | Exigiria reconfiguração adicional; Docker Desktop já era usado pela equipe | Não adotado (Docker Desktop já atendia) |

### 3.2 Topologia

```
Docker Desktop (Kubernetes habilitado)
└── Namespace: fiapx
    ├── Deployments: auth-service (8090), video-upload-service (8083),
    │                video-processing-service (8086), video-status-service (8084),
    │                video-download-service (8085), notification-service (8087)
    ├── StatefulSets: postgres-auth, postgres-upload, postgres-processing, postgres-status
    ├── StatefulSet: rabbitmq (exchange video.events + filas, ver RFC-004)
    ├── Deployment: mailhog (SMTP mock, UI :8025)
    ├── Helm release: ingress-nginx (Ingress único, path-based — ver ADR-003)
    └── Helm release: prometheus (+ ConfigMaps de dashboards Grafana do repo observability)
```

Todo o provisionamento é feito com `terraform apply`, usando os providers:

```hcl
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kube_context   # default: "docker-desktop"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.kube_context
  }
}
```

### 3.3 Componentes provisionados

| Componente | Recurso Terraform | Descrição |
|---|---|---|
| Namespace | `kubernetes_namespace_v1.fiapx` | Namespace único compartilhado por todos os microsserviços |
| Mensageria | `kubernetes_stateful_set_v1.rabbitmq` (`infra/rabbitmq.tf`) | RabbitMQ com definições de exchange/filas/DLQ carregadas via Secret (ver RFC-004) |
| Banco de dados | `kubernetes_stateful_set_v1.postgres` (`infra/postgres.tf`, `for_each`) | Um StatefulSet PostgreSQL por microsserviço (ver ADR-004) |
| Ingress | `helm_release.ingress_nginx` + `kubernetes_ingress_v1.fiapx` (`infra/ingress.tf`) | Porta de entrada HTTP única, roteada por path (ver ADR-003) |
| SMTP mock | `kubernetes_deployment_v1.mailhog` (`infra/mailhog.tf`) | Substitui um provedor de e-mail real (SES/SMTP) para testes locais |
| Observabilidade | `helm_release.prometheus` + ConfigMaps de dashboards (`infra/observability.tf`) | Coleta métricas dos microsserviços e importa dashboards do repositório `observability` |
| Segredos | `kubernetes_secret_v1.*` (`infra/secrets.tf`) | JWT compartilhado, credenciais RabbitMQ, credenciais PostgreSQL por serviço, licença New Relic |
| Acesso local | `infra/loadbalancers.tf` | Expõe RabbitMQ AMQP e cada PostgreSQL em portas distintas de `localhost`, para debug via IDE/DBeaver |

---

## 4. Alternativas Rejeitadas

### 4.1 Amazon EKS + VPC + NLB + API Gateway (arquitetura original, revogada)
- Dependia de conta AWS ativa e créditos (cenário de uma fase anterior do curso, "AWS Academy");
- Sem essa infraestrutura disponível atualmente, o RFC foi revisado para refletir o ambiente 100% local.

### 4.2 Docker Compose (sem Kubernetes)
- Mais simples de operar, porém não atenderia ao requisito de demonstrar orquestração via Kubernetes;
- Rejeitado — o enunciado do desafio aceita "Docker + Kubernetes **ou** Docker Compose", e a equipe optou por demonstrar Kubernetes.

### 4.3 kind / minikube
- Alternativas locais válidas e gratuitas;
- Não adotadas por não trazerem vantagem sobre o Kubernetes já embutido no Docker Desktop, já em uso pela equipe.

---

## 5. Consequências

### Positivas
- **Custo zero** — nenhuma dependência de conta de nuvem ou créditos;
- Ambiente **100% reprodutível** em qualquer máquina com Docker Desktop + Kubernetes habilitado, via `terraform apply`;
- Toda a infraestrutura (mensageria, banco, ingress, observabilidade) é declarativa e versionada;
- Elimina os riscos de expiração de credenciais/sessões temporárias que existiam no cenário AWS Academy anterior.

### Negativas / Riscos
- Não reflete fielmente um ambiente de produção real (sem múltiplos nós, sem alta disponibilidade, sem balanceamento de carga gerenciado por nuvem);
- Recursos (CPU/memória) limitados à máquina local que roda o Docker Desktop;
- Portabilidade para nuvem exigiria revisar novamente os providers do Terraform e recriar recursos equivalentes (RDS, ALB/NLB, EKS) caso o projeto volte a rodar em produção real.

---

## 6. Referências

- [Terraform Provider: Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Provider: Helm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- `docs/requirements/POSTECH - SOAT - Fase 5 - Hacka.txt` (workspace raiz) — stack tecnológica recomendada.

**RFC relacionado:** RFC-004 (Arquitetura geral e fluxo de mensageria). **ADR relacionado:** ADR-003 (Ingress NGINX), ADR-004 (Banco de dados local por serviço), ADR-005 (Nomenclatura de filas RabbitMQ).
