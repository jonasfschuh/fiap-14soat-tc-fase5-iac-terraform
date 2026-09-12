# ADR-004 — PostgreSQL Local (StatefulSet), Um Banco de Dados por Microsserviço

| Campo           | Valor                                                                          |
|-----------------|--------------------------------------------------------------------------------|
| **ADR**         | 004                                                                            |
| **Título**      | Um StatefulSet PostgreSQL dedicado por microsserviço, provisionado localmente no cluster Kubernetes |
| **Repositório** | fiap-14soat-tc-fase5-iac-terraform                                             |
| **Status**      | Aceito — **revisado em 2026-09-10** (substitui a versão anterior baseada em RDS/AWS Academy) |
| **Data**        | 2026-07-20 (criado) · 2026-09-10 (revisado — remoção de toda dependência AWS)  |
| **Decisores**   | Time FIAP 14SOAT Fase 5                                                        |
| **Referência**  | RFC-004 — Arquitetura Geral e Fluxo de Mensageria                              |

---

## ⚠️ Nota sobre a revisão

A versão original deste ADR descrevia uma **instância RDS PostgreSQL compartilhada no AWS Academy**, citando microsserviços de outro domínio (`ms-customer`, `ms-vehicle`, `ms-service`, `ms-stocks`, `ms-purchase-order`, `ms-billing` — de uma fase anterior do curso, projeto "RaceForce" de oficina mecânica). Essa arquitetura **não corresponde ao projeto atual**: não existe conta AWS, RDS ou orçamento do AWS Academy envolvidos. O Terraform real (`infra/postgres.tf` + `infra/secrets.tf`) provisiona **PostgreSQL como StatefulSets dentro do próprio cluster Kubernetes local (Docker Desktop)**, um por microsserviço. Esta revisão substitui o conteúdo original pela decisão efetivamente implementada.

---

## Contexto

A arquitetura de microsserviços da plataforma de processamento de vídeos segue o padrão **Database-per-Service**: cada microsserviço que precisa persistir dados possui seu **próprio banco de dados isolado**, sem acesso direto aos dados dos demais. Os microsserviços que utilizam PostgreSQL hoje são:

| Microsserviço | Usa banco próprio? | Observação |
|---|---|---|
| `auth` | ✅ Sim (`auth_db`) | Tabela `users` via Flyway |
| `video-upload-service` | ✅ Sim (`video_upload_db`) | Tabela `videos` via Flyway |
| `video-status-service` | ✅ Sim (`video_status_db`) | Tabela `videos` via Flyway |
| `video-processing-service` | ⚠️ Banco provisionado (`video_processing_db`), mas **sem migration/uso identificado no código atual** | Ver seção "Observação" abaixo — mantido como está, sem alteração neste momento |
| `video-download-service` | ❌ Não usa banco próprio | Lê arquivos do PersistentVolume compartilhado (`infra/storage.tf`) |
| `notification-service` | ❌ Não usa banco próprio | Apenas consome eventos do RabbitMQ e envia e-mail via MailHog (local) |

Diferente de um ambiente de produção real (onde cada serviço teria sua própria instância de banco gerenciada), o ambiente é um **cluster Kubernetes local no Docker Desktop**, sem custo de nuvem e sem as restrições de orçamento/sessão do AWS Academy que motivavam a decisão anterior.

---

## Decisão

**Provisionar um `StatefulSet` PostgreSQL 16 (imagem `postgres:16-alpine`) dedicado por microsserviço**, cada um com seu próprio `Service` (`ClusterIP: None`, headless), `Secret` de credenciais e `PersistentVolumeClaim` de 1Gi, todos gerenciados pelo módulo `infra/postgres.tf` + `infra/secrets.tf` do `iac-terraform`:

| Microsserviço | StatefulSet/Service | Banco (`db_name`) | Secret |
|---|---|---|---|
| `auth` | `postgres-auth` | `auth_db` | `postgres-auth-secret` |
| `video-upload-service` | `postgres-upload` | `video_upload_db` | `postgres-upload-secret` |
| `video-processing-service` | `postgres-processing` | `video_processing_db` | `postgres-processing-secret` |
| `video-status-service` | `postgres-status` | `video_status_db` | `postgres-status-secret` |

Cada `Secret` publica as credenciais no formato de variáveis do Spring Boot (`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`), consumidas diretamente pelo `Deployment` de cada microsserviço.

---

## Justificativa

### Comparação de cenários

| Critério | 1 instância RDS compartilhada (arquitetura anterior/AWS) | 1 StatefulSet PostgreSQL por serviço no cluster local (adotado) |
|---|---|---|
| **Custo mensal** | ~$15/mês (AWS Academy) | **$0** — roda localmente no Docker Desktop |
| **Isolamento físico** | Parcial — instância única, DATABASE separado | **Total** — Pod, volume e processo PostgreSQL dedicados por serviço |
| **Isolamento lógico** | Total (DATABASE separado por MS) | **Total** — Pod, Service e Secret próprios |
| **Dependência de infraestrutura externa** | AWS Academy (sessões de 4h, créditos limitados) | Nenhuma — apenas Docker Desktop local |
| **Viabilidade sem conta AWS** | ❌ Inviável | ✅ Totalmente viável |
| **Independência de configuração** | Baixa (parâmetros compartilhados na instância) | **Alta** — cada StatefulSet pode ter seus próprios `resources.limits`/`requests` |
| **Tempo de provisionamento** | ~8min (1 × Terraform apply na AWS) | Poucos segundos por Pod (`kubernetes_stateful_set_v1`) |

### Garantias preservadas do padrão Database-per-Service

1. **Isolamento de acesso**: cada microsserviço conecta-se **apenas ao seu próprio Pod/Service PostgreSQL** via `SPRING_DATASOURCE_URL` exclusivo;
2. **Isolamento físico real**: diferente da instância RDS compartilhada anterior, agora cada serviço tem seu **próprio processo PostgreSQL, volume (`PersistentVolumeClaim`) e recursos de CPU/memória**;
3. **Independência de deploy**: uma nova migration Flyway em `video-status-service` não afeta `auth` ou `video-upload-service`;
4. **Sem acesso direto entre serviços**: toda troca de dados ocorre exclusivamente via **RabbitMQ** (mensageria) ou API REST — nenhum microsserviço acessa o banco de outro.

---

## Consequências

### Positivas

- ✅ Custo zero — não há mais dependência de créditos/orçamento de nuvem;
- ✅ Isolamento físico **superior** ao cenário anterior (RDS compartilhado) — cada serviço tem seu próprio Pod PostgreSQL;
- ✅ Simplicidade de provisionamento — `terraform apply` sobe todos os bancos localmente em segundos;
- ✅ Sem compartilhamento de credenciais entre serviços — cada um possui `Secret` exclusivo;
- ✅ Flyway migrations por serviço sem qualquer risco de colisão de schema entre bancos.

### Negativas / Riscos

- ⚠️ **Não reflete um ambiente de produção real**: em produção, cada banco deveria rodar em uma instância gerenciada (RDS, Cloud SQL, etc.) com backup automatizado, réplica e monitoramento dedicado — o `StatefulSet` local não oferece isso;
- ⚠️ **Sem backup automatizado**: os dados residem em `PersistentVolumeClaim` local (Docker Desktop) — perda do volume implica perda de dados, sem snapshot automático;
- ⚠️ **Sem alta disponibilidade**: `replicas = 1` por StatefulSet — uma falha do Pod interrompe o banco daquele serviço até o Kubernetes recriá-lo;
- ⚠️ **`video_processing_db` provisionado mas não utilizado** — nenhuma migration Flyway ou configuração de datasource foi localizada em `video-processing-service` até o momento. **Decisão explícita:** manter como está por ora (fora do escopo desta revisão); uma reavaliação futura pode decidir remover o banco do Terraform ou utilizá-lo (ex.: idempotência de mensagens processadas).

> ⚠️ Esta decisão prioriza **simplicidade e custo zero para fins acadêmicos/demonstração local**. Em um ambiente de produção real, cada microsserviço deveria ter sua própria instância de banco gerenciada, com backup, réplica e monitoramento independentes.

---

## Alternativas Consideradas

### RDS PostgreSQL compartilhado na AWS (arquitetura original, revogada)
- Adequada apenas com conta AWS ativa (AWS Academy de uma fase anterior do curso);
- Sem essa infraestrutura disponível, tornou-se inaplicável ao projeto atual.

### Uma única instância PostgreSQL local compartilhada (multi-database, sem StatefulSet por serviço)
- Reduziria o número de Pods no cluster local;
- Rejeitada: seria um retrocesso ao mesmo problema de acoplamento/SPOF que a instância RDS compartilhada já tinha, sem sequer o benefício de estar gerenciada por um provedor de nuvem.

### PostgreSQL externo ao cluster (ex.: instalado diretamente no host Windows)
- Evitaria uso de `PersistentVolumeClaim`;
- Rejeitada: acoplaria a solução ao ambiente específico da máquina do desenvolvedor, dificultando a reprodutibilidade via `terraform apply`.

---

## Notas de Implementação

```hcl
# infra/secrets.tf — mapeamento real dos bancos por microsserviço
locals {
  postgres_databases = {
    auth       = { service_name = "postgres-auth",       secret_name = "postgres-auth-secret",       db_name = "auth_db" }
    upload     = { service_name = "postgres-upload",     secret_name = "postgres-upload-secret",     db_name = "video_upload_db" }
    processing = { service_name = "postgres-processing", secret_name = "postgres-processing-secret", db_name = "video_processing_db" }
    status     = { service_name = "postgres-status",     secret_name = "postgres-status-secret",     db_name = "video_status_db" }
  }
}

# infra/postgres.tf — um StatefulSet por banco, imagem oficial postgres:16-alpine
resource "kubernetes_stateful_set_v1" "postgres" {
  for_each = local.postgres_databases
  # ... container postgres:16-alpine, PVC de 1Gi, env vars via Secret
}
```

Portas expostas em `localhost` para desenvolvimento (via `infra/loadbalancers.tf`): `auth` → `5430`, `upload` → `5433`, `status` → `5434`, `processing` → `5435`.

**ADR relacionado:** ADR-001 (`auth` — JWT via Spring Security), ADR-003 (Ingress NGINX local), RFC-004 (Arquitetura geral e fluxo de mensageria).
