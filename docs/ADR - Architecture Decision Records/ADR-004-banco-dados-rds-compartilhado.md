# ADR-004 — Instância RDS PostgreSQL Compartilhada entre Microserviços

| Campo           | Valor                                                                          |
|-----------------|--------------------------------------------------------------------------------|
| **ADR**         | 004                                                                            |
| **Título**      | Consolidação dos bancos PostgreSQL em uma única instância RDS compartilhada    |
| **Repositório** | fiap-14soat-tc-fase4-iac-terraform                                             |
| **Status**      | Aceito — decisão acadêmica, não recomendada para produção                      |
| **Data**        | 2026-07-20                                                                     |
| **Decisores**   | Time FIAP 14SOAT Fase 4 — RaceForce                                            |
| **Referência**  | RFC-004 — Estratégia de Banco de Dados Compartilhado (AWS Academy)             |

---

## Contexto

A arquitetura de microserviços da plataforma RaceForce (Fase 4) prevê o padrão **Database-per-Service**: cada microserviço deve possuir seu banco de dados exclusivo, sem acesso direto aos dados dos demais. Para os 6 microserviços que utilizam PostgreSQL (`ms-customer`, `ms-vehicle`, `ms-service`, `ms-stocks`, `ms-purchase-order`, `ms-billing`), o cenário ideal seria provisionar **6 instâncias RDS separadas**.

O ambiente de desenvolvimento e validação acadêmica é o **AWS Academy**, que impõe restrições severas:

- Orçamento de **$50–100/mês** em créditos (não renováveis);
- Sessões de **4 horas** com credenciais temporárias que expiram ao término;
- Instâncias RDS continuam consumindo crédito enquanto ativas, mesmo fora das sessões de trabalho.

A equipe precisou escolher entre manter a pureza arquitetural (6 instâncias RDS) ou viabilizar a entrega acadêmica dentro do orçamento disponível.

---

## Decisão

**Provisionar uma única instância `db.t3.micro` RDS PostgreSQL 16**, centralizada no repositório `fiap-14soat-tc-fase4-iac-terraform`, na qual cada microserviço possui seu próprio **DATABASE isolado** (não schema, mas banco lógico separado), com usuário e senha exclusivos por serviço.

| Microserviço        | DATABASE criado          | Usuário       |
|---------------------|--------------------------|---------------|
| `ms-customer`       | `customer_db`            | `customer`    |
| `ms-vehicle`        | `vehicle_db`             | `vehicle`     |
| `ms-service`        | `service_db`             | `service`     |
| `ms-stocks`         | `stocks_db`              | `stocks`      |
| `ms-purchase-order` | `purchase_order_db`      | `purchaseord` |
| `ms-billing`        | `billing_db`             | `billing`     |

A instância RDS é provisionada pelo Terraform do `iac-terraform`. Cada repositório de microserviço cria seu banco via `psql CREATE DATABASE` no pipeline `deploy_infra.yaml`, sem precisar de um módulo Terraform individual.

---

## Justificativa

### Comparação de cenários

| Critério                      | 6 instâncias RDS dedicadas (ideal)       | 1 instância RDS compartilhada (adotado) |
|-------------------------------|------------------------------------------|-----------------------------------------|
| **Custo mensal estimado**     | ~$73/mês (6 × `db.t3.micro`)            | **~$15/mês** (1 × `db.t3.micro`)        |
| **Isolamento físico**         | Total — instância dedicada por MS        | Parcial — DATABASE separado por MS       |
| **Isolamento lógico**         | Total                                    | **Total** — conexão exclusiva ao seu DB  |
| **Independência de configuração** | Alta — parâmetros por instância       | Baixa — configuração compartilhada       |
| **Viabilidade no AWS Academy**| ❌ Inviável — excede o orçamento        | ✅ Viável — dentro do budget              |
| **Risco de vazamento de dados** | Mínimo                                 | Baixo — usuários sem acesso cruzado      |
| **Tempo de provisionamento**  | ~30min (6 × Terraform apply)             | ~8min (1 × Terraform apply)              |

### Garantias preservadas

Embora a instância seja compartilhada, as seguintes garantias do padrão **Database-per-Service** são preservadas:

1. **Isolamento de acesso**: cada microserviço conecta-se **apenas ao seu DATABASE** via string de conexão exclusiva (`SPRING_DATASOURCE_URL`). O usuário do MS não tem permissão em outros bancos.
2. **Isolamento de schema**: as migrations Flyway de cada MS operam apenas dentro do seu DATABASE — não há risco de colisão de tabelas entre serviços.
3. **Independência de deploy**: um novo schema ou migration em `ms-stocks` não afeta `ms-customer`.
4. **Sem acesso direto entre serviços**: toda troca de dados continua ocorrendo exclusivamente via API REST ou mensageria SQS/SNS — nenhum MS acessa o DATABASE do outro.

### Motivação para centralizar no `iac-terraform`

A instância RDS é gerenciada pelo repositório de infraestrutura central porque:
- É um recurso compartilhado entre múltiplos microserviços — faz sentido viver no repositório que gerencia toda a infraestrutura base;
- Evita que cada repositório de MS precise provisionar e destruir sua própria instância RDS (risco de conflito de endpoints e custos duplicados);
- O endpoint RDS é publicado no **Terraform state remoto (S3)** e consumido via `terraform_remote_state` por cada pipeline de MS.

---

## Consequências

### Positivas

- ✅ Custo reduzido de ~$73/mês para ~$15/mês — dentro do orçamento do AWS Academy;
- ✅ Provisionamento único e centralizado via Terraform no repositório de infraestrutura;
- ✅ Isolamento lógico total preservado — cada MS vê apenas seu próprio DATABASE;
- ✅ Sem compartilhamento de credenciais — cada MS possui usuário/senha exclusivos;
- ✅ Flyway migrations por MS sem colisão de schema;
- ✅ Endpoint RDS compartilhado via Terraform Remote State — sem duplicação de configuração.

### Negativas / Riscos

- ⚠️ **Sem isolamento físico de recursos**: alta carga em um MS pode afetar a performance do banco de outro MS na mesma instância (contenção de CPU/I/O da instância `db.t3.micro`);
- ⚠️ **Ponto único de falha (SPOF)**: uma falha na instância RDS afeta simultaneamente todos os 6 microserviços que dependem de PostgreSQL;
- ⚠️ **Sem configuração independente de parâmetros**: não é possível ajustar `max_connections`, `work_mem` ou `shared_buffers` por MS;
- ⚠️ **Backup unificado**: a política de backup é a mesma para todos os bancos na instância — sem granularidade por MS.

> ⚠️ **Esta decisão é exclusivamente acadêmica**. Em um ambiente de produção real, cada microserviço deve ter sua própria instância RDS dedicada, com configurações de performance, backup e disaster recovery independentes.

---

## Alternativas Consideradas

### 6 instâncias RDS dedicadas (cenário ideal de produção)
- Isolamento físico total;
- Custo ~$73/mês — inviável para o orçamento de $50/mês do AWS Academy;
- Tempo de provisionamento impraticável dentro da janela de 4 horas por sessão.

### PostgreSQL em container no EKS (sem RDS)
- Sem custo adicional de RDS;
- Sem gerenciamento de backups, snapshots, patching;
- Risco de perda de dados em caso de falha de pod (volumes EBS sem gestão automatizada);
- Inaceitável para dados persistentes de negócio.

### Amazon Aurora Serverless v2
- Escala automaticamente — ideal para cargas variáveis;
- Custo mínimo de ~$43/mês (0,5 ACU × $0,12/hora) — ainda acima do viável para 6 instâncias;
- Incompatível com o nível Free Tier elegível do `db.t3.micro`.

---

## Notas de Implementação

```hcl
# infra/rds.tf — instância compartilhada provisionada pelo iac-terraform
resource "aws_db_instance" "postgres_shared" {
  identifier        = "rds-fiap-14soat-fase4-raceforce"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "postgres"
  username = var.db_master_username
  password = var.db_master_password

  skip_final_snapshot = true
  publicly_accessible = false
  # Security Group: acesso apenas do node group do EKS
}
```

```bash
# deploy_infra.yaml de cada MS — cria o DATABASE isolado na instância compartilhada
psql "host=$RDS_ENDPOINT port=5432 dbname=postgres user=$DB_MASTER_USER password=$DB_MASTER_PASS" \
  -c "CREATE DATABASE customer_db;"
psql ... -c "CREATE USER customer WITH PASSWORD '$DB_PASSWORD';"
psql ... -c "GRANT ALL PRIVILEGES ON DATABASE customer_db TO customer;"
```

**ADR relacionado:** ADR-003 (NLB Interno + VPC Link), RFC-004 (Estratégia de Banco Compartilhado AWS Academy).
