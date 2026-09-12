# ADR-005 — Padronização de Nomenclatura das Filas RabbitMQ (hífen para filas, ponto para routing keys)

| Campo        | Valor                                                                 |
|--------------|-------------------------------------------------------------------------|
| **ADR**      | 005                                                                   |
| **Título**   | Padronizar nomes de fila com hífen (`-`) e manter routing keys/exchanges com ponto (`.`) |
| **Repositório** | fiap-14soat-tc-fase5-iac-terraform                                    |
| **Status**   | Aceito                                                                |
| **Data**     | 2026-09-10                                                            |
| **Decisores**| Time FIAP 14SOAT Fase 5                                               |
| **Origem**   | Formaliza a proposta `proposta-padronizacao-filas-rabbitmq.md` (raiz do workspace) |

---

## Contexto

O projeto usava dois padrões de separador coexistindo nos nomes das filas RabbitMQ:

- **Ponto** (`.`): `notification.email.requested`, `video.processing.completed`, `video.uploaded.dlq`;
- **Hífen** (`-`): `video-events`, `video-uploaded`, `video-events-dlq`.

Essa inconsistência dificultava a leitura da topologia de mensageria e criava ambiguidade entre o que é **nome de fila** e o que é **routing key** — já que ambos podiam usar o mesmo caractere separador.

---

## Decisão

**Padronizar todos os nomes de fila (e suas DLQs) com hífen (`-`)**. Os **routing keys** do exchange `video.events` continuam usando ponto (`.`) — essa é a convenção oficial do protocolo AMQP para exchanges do tipo `topic` (ex.: `video.uploaded`, `video.processed`, `video.failed`). A mudança afeta **apenas os nomes das filas e DLQs**, nunca os routing keys ou o nome do exchange.

### Mapeamento aplicado

| Nome antigo | Nome padronizado |
|---|---|
| `video.upload.requested` | `video-upload-requested` |
| `video.processing.requested` | `video-processing-requested` |
| `video.processing.completed` | `video-processing-completed` |
| `video.status.updated` | `video-status-updated` |
| `notification.email.requested` | `notification-email-requested` |
| `video.uploaded.dlq` (nome de fila) | `video-uploaded-dlq` |
| `video.processed.dlq` (nome de fila) | `video-processed-dlq` |

### Filas ativas hoje (já seguem o padrão)

| Fila | Produzida por | Consumida por |
|---|---|---|
| `video-uploaded` | `video-upload-service` | `video-processing-service` |
| `video-uploaded-dlq` | RabbitMQ (dead-letter) | Monitoramento |
| `video-processed` | `video-processing-service` | `video-upload-service` (feedback) |
| `video-processed-dlq` | RabbitMQ (dead-letter) | Monitoramento |
| `video-events` | `video-processing-service` | `video-status-service`, `notification-service` |
| `video-events-dlq` | RabbitMQ (dead-letter) | Monitoramento |
| `video-status-uploaded` | `video-upload-service` | `video-status-service` |
| `video-status-uploaded-dlq` | RabbitMQ (dead-letter) | Monitoramento |

### Routing keys — sem alteração (convenção AMQP mantida)

| Routing Key | Uso |
|---|---|
| `video.uploaded` | Binding principal → `video-uploaded`, `video-status-uploaded` |
| `video.processed` | Binding principal → `video-processed`, `video-events` |
| `video.failed` | Binding principal → `video-events` |
| `video.uploaded.dlq` | DLQ routing key → `video-uploaded-dlq` |
| `video.processed.dlq` | DLQ routing key → `video-processed-dlq` |
| `video.events.dlq` | DLQ routing key → `video-events-dlq` |
| `video.status.uploaded.dlq` | DLQ routing key → `video-status-uploaded-dlq` |

---

## Justificativa

| Critério | Hífen para filas / ponto para routing keys (escolhido) | Ponto para tudo | Hífen para tudo |
|---|---|---|---|
| Compatibilidade com convenção AMQP (topic exchange) | Sim — routing keys com `.` permitem wildcards (`*`, `#`) | Sim, mas ambíguo com nomes de fila | Quebra a convenção de routing key hierárquica |
| Legibilidade do nome da fila | Alta — hífen é o padrão usual de nomes de recursos (Kubernetes, filas, etc.) | Pode ser confundido com routing key | Alta |
| Ambiguidade fila vs. routing key | **Nenhuma** — visualmente distinguíveis | Alta — mesmo caractere para os dois conceitos | Perde a hierarquia de wildcard do AMQP |

---

## Consequências

### Positivas
- Elimina a ambiguidade entre nome de fila e routing key na topologia RabbitMQ;
- Mantém compatibilidade total com wildcards de topic exchange (`video.*`, `video.#`) nos routing keys;
- Facilita a leitura do `infra/rabbitmq.tf` e da documentação (ver diagrama `rabbitmq-topology.png`).

### Negativas / Riscos
- Renomear uma fila em produção exige atenção: mensagens pendentes na fila antiga precisam ser drenadas ou descartadas antes da exclusão;
- Serviços que ainda produzam/consumam filas legadas com `.` precisam ser atualizados antes da remoção definitiva.

---

## Notas de Implementação

Arquivos afetados (aplicado neste ciclo de revisão de documentação — a aplicação efetiva no Terraform/código já está registrada em `proposta-padronizacao-filas-rabbitmq.md` na raiz do workspace):

```
fiap-14soat-tc-fase5-iac-terraform
  └── infra/rabbitmq.tf                                    → nomes de fila padronizados com hífen

fiap-14soat-tc-fase5-video-upload-service
  ├── .../configuration/RabbitMqConfiguration.java         → constantes de nome de fila com hífen
  └── .../configuration/RabbitMqConfigurationTest.java     → asserções atualizadas

fiap-14soat-tc-fase5-notification-service
  └── .../messaging/RabbitVideoEventsConsumerAdapter.java  → usa constante ao invés de string literal
```

**ADR relacionado:** RFC-004 (Arquitetura geral e fluxo de mensageria), diagrama `docs/diagrams/rabbitmq-topology.png`.
