# RFC-003 — Infraestrutura Kubernetes na AWS com Terraform

| Campo        | Valor                                                   |
|--------------|---------------------------------------------------------|
| **RFC**      | 003                                                     |
| **Título**   | Provisionamento do Cluster EKS, VPC e NLB com Terraform |
| **Repositório** | fiap-14soat-tc-fase4-iac-terraform                      |
| **Status**   | Aceito                                                  |
| **Autor**    | Time FIAP 14SOAT Fase 4                                |
| **Data**     | 2026-04-20 (criado) · 2026-07-17 (revisado — SQS, RDS, SNS adicionados) |

---

## 1. Resumo

Este documento justifica as escolhas de infraestrutura como código (IaC) para provisionamento do cluster Kubernetes gerenciado (**Amazon EKS**), rede (**VPC + subnets + IGW**), balanceamento de carga (**NLB interno**) e monitoramento (**New Relic nri-bundle via Helm**) utilizando **Terraform**.

---

## 2. Motivação

O Tech Challenge exige:

- Cluster Kubernetes com **escalabilidade**;
- Provisionamento via **Terraform**;
- Infraestrutura reproduzível entre sessões do **AWS Academy** (credenciais renovadas a cada sessão);
- Integração com New Relic para observabilidade.

---

## 3. Proposta

### 3.1 Escolha da Nuvem — AWS

| Opção | Prós | Contras | Decisão |
|-------|------|---------|---------|
| **AWS** | AWS Academy disponível, EKS gerenciado, Lambda nativa | Custo fora do Academy | **Escolhida** |
| GCP (GKE) | Autopilot facilita gestão | Sem créditos gratuitos no contexto do curso | Rejeitado |
| Azure (AKS) | Integração com Azure AD | Sem créditos gratuitos no contexto do curso | Rejeitado |

### 3.2 Escolha do Kubernetes Gerenciado — Amazon EKS

| Opção | Prós | Contras | Decisão |
|-------|------|---------|---------|
| **EKS** | Gerenciado pela AWS, integração IAM nativa | Mais complexo que Fargate | **Escolhido** |
| ECS Fargate | Serverless containers | Não é Kubernetes (requisito do enunciado) | Rejeitado |
| k3s em EC2 | Baixo custo | Sem gerenciamento, manutenção manual | Rejeitado |

### 3.3 Topologia de Rede

```
VPC (10.0.0.0/16)
├── Subnet us-east-1a (pública)
├── Subnet us-east-1b (pública)
├── Subnet us-east-1c (pública)
├── Internet Gateway
└── Route Table → 0.0.0.0/0 → IGW
```

> Subnets públicas foram escolhidas para simplificar o acesso no contexto do AWS Academy (sem NAT Gateway pago).

### 3.4 Estratégia de Acesso Externo — NLB Interno + API Gateway

```
Internet → API Gateway (público)
              ↓ VPC Link
           NLB (internal=true)
              ↓ Target: NodePort 30000
           EKS Node Group
              ↓
           K8s Service → Pod
```

O NLB é **interno** (`internal = true`), ou seja:
- **Não exposto diretamente na internet**;
- Acessível apenas via **VPC Link** do API Gateway;
- Garante que o único ponto de entrada externo seja o API Gateway.

### 3.5 Node Group

| Parâmetro | Valor | Justificativa |
|-----------|-------|---------------|
| Tipo de instância | `t3.medium` | Suporta pods da aplicação + New Relic agents |
| Min nodes | 1 | Custo mínimo no Academy |
| Max nodes | 2 | Permite escala sem estourar limites da conta |
| AMI | Amazon Linux 2 (EKS optimized) | Padrão recomendado pela AWS |

### 3.6 New Relic — Instalação via Helm no Terraform

O chart `nri-bundle` é instalado via `helm_release` no próprio pipeline Terraform, ativado pela variável `TF_VAR_ENABLE_NEW_RELIC=true`. Inclui:

- `nrk8s-kubelet` — métricas de CPU/memória por pod/node
- `nrk8s-ksm` (kube-state-metrics) — estado dos objetos K8s
- `nri-kube-events` — eventos do cluster
- `newrelic-prometheus-agent` — scrape do `/actuator/prometheus`
- `newrelic-logging` — logs estruturados JSON
- `nr-ebpf-agent` — rastreamento de rede e APM automático

### 3.7 State Remoto

```hcl
backend "s3" {
  bucket = "fiap-14soat-fase4-jonasfschuh"
  key    = "infra/terraform.tfstate"
  region = "us-east-1"
}
```

Outputs publicados (consumidos via `terraform_remote_state` pelos repositórios de cada microserviço):

| Output | Descrição |
|--------|-----------|
| `vpc_principal_id` | ID da VPC |
| `vpc_principal_cidr` | Bloco CIDR da VPC |
| `subnet_publica_ids` | IDs das subnets públicas (us-east-1a/b/c/d/f) |
| `eks_cluster_name` | Nome do cluster EKS |
| `nlb_dns_name` | DNS do NLB interno |
| `nlb_arn` | ARN do NLB |
| `nlb_listener_arn` | ARN do listener principal (ms-service-order, porta 80) |
| `nlb_ms_listener_arns` | ARNs dos listeners por MS (customer, vehicle, service, stocks, billing, purchase-order) |
| `rds_endpoint` | Endpoint `host:port` da instância RDS compartilhada |
| `rds_host` | Hostname da instância RDS |
| `rds_port` | Porta da instância RDS (5432) |
| `saga_queue_arns` | ARNs das 4 filas SAGA SQS |
| `saga_queue_urls` | URLs das 4 filas SAGA SQS |
| `saga_dlq_arns` | ARNs das DLQs das filas SAGA |
| `domain_event_queue_urls` | URLs das filas de eventos de domínio |
| `domain_event_queue_arns` | ARNs das filas de eventos de domínio |
| `sns_topic_arns` | ARNs dos 3 tópicos SNS de purchase-order |

### 3.8 SQS — Filas SAGA e Eventos de Domínio

As filas SQS são provisionadas pelo arquivo `sqs-saga.tf`, seguindo o padrão **SAGA Orquestrado** (ADR-013):

**Filas SAGA (so-commands / so-replies):**

| Fila | Produtor | Consumidor |
|------|----------|------------|
| `so-commands-purchase-order` | ms-service-order | ms-purchase-order |
| `so-commands-stocks` | ms-service-order | ms-stocks |
| `so-commands-billing` | ms-service-order | ms-billing |
| `so-replies` | ms-purchase-order, ms-stocks, ms-billing | ms-service-order |

**Filas de Eventos de Domínio:**

| Fila | Produtor | Consumidor |
|------|----------|------------|
| `payment-confirmed` | ms-billing (webhook Mercado Pago) | ms-service-order |
| `service-order-completed` | ms-service-order | — (notificações futuras) |
| `purchase-order-events` | ms-purchase-order | ms-service-order |

**Configuração das filas:**

```hcl
# Todas as filas têm DLQ com retenção de 7 dias e maxReceiveCount = 3
visibility_timeout_seconds = 30
message_retention_seconds  = 86400  # 24h nas filas principais
message_retention_seconds  = 604800 # 7 dias nas DLQs
maxReceiveCount            = 3
```

### 3.9 RDS PostgreSQL Compartilhado

Para reduzir custo dentro do limite de $50 do AWS Academy, uma única instância RDS centraliza os 6 bancos PostgreSQL dos microserviços (`customer`, `vehicle`, `service`, `stocks`, `billing`, `purchase_order`):

| Parâmetro | Valor | Justificativa |
|-----------|-------|---------------|
| Identificador | `raceforce-shared-postgres` | Instância única compartilhada |
| Engine | PostgreSQL 16 | Versão LTS atual |
| Instância | `db.t3.micro` | Free tier + custo ~$12/mês |
| Storage | 20 GB GP2 (fixo) | Sem autoscaling para controle de custo |
| Custo estimado | ~$14,30/mês | vs ~$73/mês com 6 instâncias separadas |
| Multi-AZ | Não | Custo/laboriações acadêmicas |
| Backup | Desabilitado | Ambiente de laboratório |
| Acesso | VPC interna + CIDR 0.0.0.0/0 para CI/CD | GitHub Actions precisa criar os bancos |

> **Nota acadêmica:** Em um ambiente de produção, cada microserviço teria sua própria instância RDS dedicada, garantindo isolamento, failover independente e dimensionamento conforme carga. A consolidação foi feita exclusivamente por restrição orçamentária e de tempo (sessão AWS Academy de 4 horas).

**Criação dos bancos individuais:** cada repositório de MS executa `psql CREATE DATABASE <ms_name>` via `deploy_infra.yaml` no pipeline GitHub Actions. O Terraform não cria os 6 bancos — cria apenas o banco padrão `postgres` na instância.

### 3.10 SNS Topics — Eventos de Purchase Order

Os tópicos SNS são provisionados pelo arquivo `sns-topics.tf` para eventos do ciclo de vida de purchase-order:

| Tópico SNS | Evento | Publicado por |
|------------|--------|---------------|
| `purchase-order-created` | Purchase order criada | ms-purchase-order |
| `purchase-order-completed` | Purchase order concluída | ms-purchase-order |
| `purchase-order-cancelled` | Purchase order cancelada | ms-purchase-order |

Os tópicos SNS complementam as filas SQS no modelo de mensageria assíncrona, permitindo múltiplos subscribers sem acoplamento direto.

---

## 4. Alternativas Rejeitadas

### 4.1 Pulumi (IaC alternativo)
- Menor adoção no mercado vs Terraform;
- Sem benefício adicional para o escopo do projeto.

### 4.2 AWS CloudFormation
- Sintaxe mais verbosa;
- Menor portabilidade entre clouds;
- Terraform já dominado pela equipe.

### 4.3 NLB Público
- Exporia o EKS diretamente sem autenticação;
- Violaria a decisão arquitetural de API Gateway como único ponto de entrada.

---

## 5. Consequências

### Positivas
- Infraestrutura 100% reproduzível via `terraform apply`;
- State compartilhado no S3 permite que todos os 7 repositórios de MS leiam outputs via `terraform_remote_state`;
- New Relic integrado desde o provisionamento da infra (flag `TF_VAR_ENABLE_NEW_RELIC=true`);
- SQS e SNS provisionados centralmente — nenhum MS precisa criar filas manualmente;
- RDS compartilhado reduz custo de ~$73/mês para ~$14,30/mês dentro do limite do AWS Academy.

### Negativas / Riscos
- AWS Academy renova credenciais periodicamente — o backend S3 e o `kubeconfig` precisam ser atualizados a cada sessão;
- `regexreplace` não disponível em versões antigas do Terraform — solução: usar `replace` ou atualizar o provider;
- RDS compartilhado introduz risco de "noisy neighbor" entre bancos — aceitável para fins acadêmicos;
- Security Group do RDS permite acesso externo (`0.0.0.0/0`) na porta 5432 para CI/CD — risco mitigado pelo uso de senha forte via GitHub Secret.

---

## 6. Referências

- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Amazon EKS — Getting Started](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
- [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- [Amazon SQS — Dead Letter Queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)
- [Amazon RDS — PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- ADR-003: NLB interno + VPC Link
- ADR-013: SAGA Orquestrado com Orquestrador Interno

