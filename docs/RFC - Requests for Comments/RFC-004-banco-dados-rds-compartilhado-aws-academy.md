# RFC-004 — Estratégia de Banco de Dados Compartilhado no AWS Academy

| Campo           | Valor                                                                       |
|-----------------|-----------------------------------------------------------------------------|
| **RFC**         | 004                                                                         |
| **Título**      | Consolidação de instâncias RDS PostgreSQL por restrições do AWS Academy     |
| **Repositório** | fiap-14soat-tc-fase4-iac-terraform                                          |
| **Status**      | Aceito — vigente na Fase 4                                                  |
| **Autor**       | Time FIAP 14SOAT Fase 4 — RaceForce                                         |
| **Data**        | 2026-07-20                                                                  |
| **ADR relacionado** | ADR-004 — Instância RDS PostgreSQL Compartilhada entre Microserviços    |

---

## 1. Resumo

Este documento justifica a decisão de consolidar os bancos de dados PostgreSQL de 6 microserviços em **uma única instância Amazon RDS `db.t3.micro`**, em vez de provisionar instâncias RDS dedicadas por microserviço. A decisão é motivada exclusivamente pelas **restrições econômicas e operacionais do ambiente AWS Academy** e não deve ser replicada em ambientes de produção.

---

## 2. Motivação

### 2.1 Arquitetura ideal (Database-per-Service)

A arquitetura de microserviços da plataforma RaceForce segue o padrão **Database-per-Service** (Martin Fowler / Chris Richardson), pelo qual cada serviço possui seu banco de dados completamente isolado — sem acesso direto aos dados dos demais. Esse padrão garante:

- Independência de deploy e evolução de schema;
- Escalabilidade e configuração de performance independentes;
- Isolamento de falhas — a queda do banco de um MS não afeta os demais;
- Liberdade tecnológica — cada MS pode usar o banco mais adequado ao seu contexto.

O cenário ideal para os 6 microserviços PostgreSQL seria:

```
ms-customer      → RDS dedicada: rds-customer      (db.t3.micro)
ms-vehicle       → RDS dedicada: rds-vehicle       (db.t3.micro)
ms-service       → RDS dedicada: rds-service       (db.t3.micro)
ms-stocks        → RDS dedicada: rds-stocks        (db.t3.micro)
ms-purchase-order → RDS dedicada: rds-purchase-order (db.t3.micro)
ms-billing       → RDS dedicada: rds-billing       (db.t3.micro)
```

Custo estimado: **6 × ~$12,41/mês = ~$74,46/mês** (instância `db.t3.micro`, 20 GB gp2, us-east-1).

### 2.2 Restrições do AWS Academy

O ambiente AWS Academy impõe limitações que tornam o cenário ideal inviável:

| Restrição | Impacto |
|-----------|---------|
| **Orçamento de créditos: $50–100/mês** | 6 instâncias RDS = ~$75/mês — consome quase todo o budget, sem margem para EKS ($73/mês), NLB, SQS, SNS e demais recursos |
| **Sessões de 4 horas com credenciais temporárias** | Credenciais expiram ao término de cada sessão; os recursos devem ser reprovisináveis rapidamente |
| **Custo contínuo das instâncias RDS** | RDS cobra por hora de execução, mesmo fora das sessões de trabalho; 6 instâncias = custo permanente alto |
| **Tempo de provisionamento** | `terraform apply` de 6 instâncias RDS leva ~30 minutos — impraticável dentro da janela de 4 horas |
| **Restrições de IAM no AWS Academy** | Não é possível criar roles personalizadas (apenas `LabRole`) — limitações que afetam recursos como Aurora IAM Auth |

---

## 3. Proposta

### 3.1 Solução adotada: instância RDS compartilhada com bancos logicamente isolados

Provisionar **uma única instância `db.t3.micro` RDS PostgreSQL 16** no repositório de infraestrutura central (`fiap-14soat-tc-fase4-iac-terraform`). Cada microserviço cria seu próprio **DATABASE** (banco lógico independente) dentro da mesma instância, com usuário e senha exclusivos.

```
Instância RDS: rds-fiap-14soat-fase4-raceforce (db.t3.micro, ~$12,41/mês)
  ├── DATABASE: customer_db      → usuário: customer      (acesso exclusivo)
  ├── DATABASE: vehicle_db       → usuário: vehicle       (acesso exclusivo)
  ├── DATABASE: service_db       → usuário: service       (acesso exclusivo)
  ├── DATABASE: stocks_db        → usuário: stocks        (acesso exclusivo)
  ├── DATABASE: purchase_order_db → usuário: purchaseord  (acesso exclusivo)
  └── DATABASE: billing_db       → usuário: billing       (acesso exclusivo)
```

**Economia:** ~$74/mês → **~$12/mês** (redução de ~84%).

### 3.2 Gerenciamento via Terraform Remote State

O endpoint RDS é publicado como output no Terraform state remoto (bucket S3 `fiap-14soat-fase4-jonasfschuh`, key `infra/terraform.tfstate`) e consumido por cada pipeline de microserviço via `data.terraform_remote_state.infra.outputs.rds_endpoint`.

```hcl
# Saída publicada pelo iac-terraform
output "rds_endpoint" {
  value = aws_db_instance.postgres_shared.endpoint
}

output "rds_port" {
  value = aws_db_instance.postgres_shared.port
}
```

```yaml
# deploy_infra.yaml de cada MS — lê o endpoint do tfstate e cria o DATABASE
- name: Get RDS endpoint from Terraform state
  run: |
    RDS_ENDPOINT=$(aws s3 cp s3://$TF_STATE_BUCKET/infra/terraform.tfstate - | \
      jq -r '.outputs.rds_endpoint.value')
    echo "RDS_ENDPOINT=$RDS_ENDPOINT" >> $GITHUB_ENV

- name: Create isolated DATABASE
  run: |
    psql "host=$RDS_ENDPOINT port=5432 dbname=postgres \
          user=$DB_MASTER_USER password=$DB_MASTER_PASS" << EOF
      CREATE DATABASE IF NOT EXISTS customer_db;
      CREATE USER customer WITH PASSWORD '$DB_PASSWORD';
      GRANT ALL PRIVILEGES ON DATABASE customer_db TO customer;
    EOF
```

### 3.3 Garantias do padrão Database-per-Service preservadas

| Garantia | Instâncias dedicadas | Instância compartilhada (adotado) |
|----------|---------------------|----------------------------------|
| Acesso exclusivo ao próprio banco | ✅ | ✅ (usuário sem permissão cruzada) |
| Isolamento de schema (tabelas) | ✅ | ✅ (DATABASE separado por MS) |
| Migrations Flyway independentes | ✅ | ✅ (cada MS migra apenas seu DATABASE) |
| Zero acesso direto entre MSs | ✅ | ✅ (comunicação via REST/SQS apenas) |
| Independência de deploy | ✅ | ✅ (schema do MS não afeta outros) |
| Isolamento físico de recursos | ✅ | ❌ (CPU/I/O compartilhados) |
| Configuração de parâmetros por MS | ✅ | ❌ (parâmetros globais da instância) |
| SPOF independente por MS | ✅ | ❌ (falha afeta todos os MSs) |

---

## 4. Análise de Alternativas

### 4.1 6 instâncias RDS dedicadas

- ✅ Isolamento físico total;
- ✅ Performance e configuração independentes;
- ❌ Custo ~$74/mês — inviável (excede budget disponível para toda a stack);
- ❌ ~30 min de provisionamento — impraticável na janela de 4 horas.

**Decisão: rejeitado por restrição de custo.**

### 4.2 PostgreSQL em container Docker no EKS (sem RDS)

- ✅ Sem custo adicional;
- ❌ Sem backups automáticos, snapshots ou patching gerenciado;
- ❌ Volumes EBS precisam ser gerenciados manualmente no EKS;
- ❌ Risco de perda de dados em caso de falha de pod ou node;
- ❌ Complexidade operacional alta (StatefulSets, PersistentVolumeClaims, StorageClasses).

**Decisão: rejeitado — dados persistentes de negócio não devem depender de volumes gerenciados manualmente.**

### 4.3 Amazon Aurora Serverless v2

- ✅ Escala automática conforme carga;
- ✅ PostgreSQL compatível;
- ❌ Mínimo de 0,5 ACU × $0,12/hora × 720h = ~$43/mês por cluster;
- ❌ Múltiplos clusters ainda excederiam o budget;
- ❌ Não elegível ao Free Tier como `db.t3.micro`.

**Decisão: rejeitado por custo.**

### 4.4 Amazon RDS Multi-AZ

- ✅ Alta disponibilidade com failover automático;
- ❌ Custo dobrado (~$25/mês por instância Multi-AZ);
- ❌ Não justificado para ambiente acadêmico sem SLA.

**Decisão: rejeitado — sobre-engenharia para contexto acadêmico.**

---

## 5. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Contenção de recursos (CPU/I/O) entre MSs | Baixa (tráfego acadêmico controlado) | Médio | Monitorar via CloudWatch; `db.t3.micro` suporta até 2 vCPUs e 1 GB RAM |
| Falha da instância RDS afeta todos os MSs | Baixa (RDS gerenciado pela AWS) | Alto | Backups automáticos diários; possibilidade de restore point-in-time |
| Aumento inesperado de conexões | Baixa | Médio | `max_connections` configurado; cada MS usa connection pool Spring (HikariCP) |
| Vazamento de dados entre MSs | Muito baixa | Alto | Usuários PostgreSQL sem permissão cruzada; testado com `psql \l` e `\du` |

---

## 6. Visão de Produção (Referência)

> Este RFC documenta uma **decisão acadêmica temporária**. Para um ambiente de produção, a arquitetura recomendada é:

```
Cenário de produção recomendado:
  ms-customer      → Amazon RDS PostgreSQL dedicado (db.t3.medium ou superior)
  ms-vehicle       → Amazon RDS PostgreSQL dedicado
  ms-service       → Amazon RDS PostgreSQL dedicado
  ms-stocks        → Amazon RDS PostgreSQL dedicado (maior throughput — operações SAGA)
  ms-purchase-order → Amazon RDS PostgreSQL dedicado
  ms-billing       → Amazon RDS PostgreSQL dedicado (compliance financeiro isolado)
  ms-service-order → MongoDB Atlas ou Amazon DocumentDB (clusters replicados)
```

Em produção, considerar também:
- **RDS Multi-AZ** para MSs críticos (`ms-billing`, `ms-service-order`);
- **Read Replicas** para MSs com alta carga de leitura (`ms-stocks`, `ms-customer`);
- **Amazon Aurora PostgreSQL** para reduzir overhead operacional com escala automática.

---

## 7. Conclusão

A consolidação dos 6 bancos PostgreSQL em uma única instância RDS é uma **decisão pragmática e consciente**, tomada para viabilizar a entrega do Tech Challenge dentro das restrições reais do ambiente AWS Academy. O isolamento lógico entre os bancos é total — nenhuma das garantias fundamentais do padrão Database-per-Service é violada no nível de acesso a dados. A única concessão é o compartilhamento físico de recursos de hardware da instância RDS.

Esta decisão foi formalizada no **ADR-004** e está documentada no README do `ms-service-order` na seção *"Otimização de Custos — AWS Academy"*.

---

**RFC relacionado:** RFC-003 (Infraestrutura Kubernetes na AWS com Terraform).  
**ADR relacionado:** ADR-004 (Instância RDS PostgreSQL Compartilhada), ADR-003 (NLB Interno + VPC Link).
