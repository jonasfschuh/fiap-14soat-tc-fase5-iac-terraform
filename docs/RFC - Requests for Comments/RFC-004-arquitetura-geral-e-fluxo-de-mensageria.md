# RFC-004 — Arquitetura Geral da Solução e Fluxo de Mensageria via RabbitMQ

| Campo        | Valor                                                   |
|--------------|-----------------------------------------------------------|
| **RFC**      | 004                                                     |
| **Título**   | Arquitetura de microsserviços ponta a ponta e topologia de mensageria (100% local) |
| **Repositório** | fiap-14soat-tc-fase5-iac-terraform                      |
| **Status**   | Aceito                                                  |
| **Autor**    | Time FIAP 14SOAT Fase 5                                |
| **Data**     | 2026-09-10                                              |

---

## 1. Resumo

Este documento descreve a arquitetura completa da plataforma de processamento de vídeos: os microsserviços envolvidos, como se comunicam via RabbitMQ, e o fluxo de ponta a ponta desde o upload de um vídeo até o download do `.zip` com os frames extraídos. Complementa o RFC-003 (focado apenas na infraestrutura Kubernetes) com uma visão de arquitetura de aplicação e de mensageria.

---

## 2. Motivação

O Hackathon exige (`docs/requirements/POSTECH - SOAT - Fase 5 - Hacka.txt`):

- Processar mais de um vídeo simultaneamente;
- Não perder requisições em picos;
- Proteção por usuário e senha;
- Listagem de status dos vídeos de um usuário;
- Notificação em caso de erro;
- Persistência de dados e arquitetura escalável.

A solução adotada divide essas responsabilidades em **6 microsserviços independentes**, comunicando-se de forma assíncrona via **RabbitMQ** (mensageria) para atender aos requisitos de processamento paralelo e resiliência a picos, e de forma síncrona via **REST** (atrás de um Ingress único) para as operações solicitadas diretamente pelo usuário.

---

## 3. Proposta

### 3.1 Componentes e responsabilidades

| Microsserviço | Responsabilidade | Porta | Banco |
|---|---|---|---|
| `auth` | Autenticação via usuário/senha, emissão e validação de JWT (ver ADR-001 do repositório `auth`) | 8090 | `auth_db` |
| `video-upload-service` | Recebe vídeo via multipart, grava no PersistentVolume compartilhado, persiste status `PENDING`, publica evento de upload | 8083 | `video_upload_db` |
| `video-processing-service` | Consome evento de upload, executa `ffmpeg` para extrair frames, gera `.zip`, publica evento de conclusão/erro | 8086 | (`video_processing_db` provisionado, uso não identificado — ver ADR-004) |
| `video-status-service` | Persiste e expõe o status dos vídeos por usuário (`PENDING` → `PROCESSING` → `DONE`/`FAILED`), atualizado via eventos | 8084 | `video_status_db` |
| `video-download-service` | Serve o `.zip` gerado a partir do PersistentVolume compartilhado quando o status é `DONE` | 8085 | — |
| `notification-service` | Consome eventos de sucesso/erro e envia e-mail (MailHog local) | 8087 | — |

Todos expostos atrás do mesmo **Ingress NGINX** (ver ADR-003), roteados por path (`/auth`, `/video-upload`, `/processing`, `/status`, `/download`, `/notify`).

### 3.2 Fluxo processual (ponta a ponta)

```
1. Usuário → POST /auth/login → auth-service
                                    ↓
                         Retorna JWT (Bearer token)

2. Usuário → POST /video-upload (multipart, Bearer token) → video-upload-service
                                    ↓
                         Grava vídeo no PersistentVolume compartilhado (fiapx-video-pvc)
                                    ↓
                         Persiste status PENDING (video_upload_db)
                                    ↓
                         Publica routing key "video.uploaded" no exchange "video.events"
                                    ↓
              ┌─────────────────────┴─────────────────────┐
              ▼                                             ▼
   Fila: video-uploaded                          Fila: video-status-uploaded
   (video-processing-service)                    (video-status-service)
              │                                             │
              ▼                                             ▼
   3. video-processing-service                   video-status-service atualiza
      baixa o vídeo do PV compartilhado,          status para PROCESSING
      executa ffmpeg (extração de frames),
      gera .zip, grava no PV compartilhado
              │
              ▼
   Publica routing key "video.processed" (sucesso) ou "video.failed" (erro)
   no exchange "video.events"
              │
              ├─────────────────────────┬─────────────────────────┐
              ▼                         ▼                         ▼
   Fila: video-processed        Fila: video-events         Fila: video-events
   (video-upload-service,       (video-status-service)     (notification-service)
    feedback interno)                   │                         │
                                         ▼                         ▼
                          4. Atualiza status para          5. Envia e-mail
                             DONE ou FAILED                   (sucesso ou falha)
                             (video_status_db)                 via MailHog

6. Usuário → GET /status/videos (Bearer token) → video-status-service
                                    ↓
                         Lista vídeos do usuário autenticado com status atual

7. Usuário → GET /download/{videoId} (Bearer token) → video-download-service
                                    ↓
                         Serve o .zip do PersistentVolume compartilhado (se status = DONE)
```

### 3.3 Topologia RabbitMQ (resumo — ver ADR-005 para o detalhamento completo)

- **Exchange:** `video.events` (tipo `topic`, durável);
- **Filas** (nomenclatura padronizada com hífen, ver ADR-005): `video-uploaded`, `video-uploaded-dlq`, `video-processed`, `video-processed-dlq`, `video-events`, `video-events-dlq`, `video-status-uploaded`, `video-status-uploaded-dlq`;
- **Routing keys** (mantêm ponto, convenção AMQP): `video.uploaded`, `video.processed`, `video.failed`, e as variantes `*.dlq` para as filas de dead-letter;
- Todas as filas possuem **Dead Letter Exchange/Queue (DLX/DLQ)** configurados, garantindo que mensagens não processadas com sucesso (após as tentativas de reentrega) não sejam perdidas — atendendo ao requisito de **"não perder uma requisição em picos"**.
- Diagrama detalhado: `docs/diagrams/rabbitmq-topology.png` / `.svg`.

### 3.4 Escalabilidade e resiliência

- Cada microsserviço consumidor (`video-processing-service`, `video-status-service`, `notification-service`) pode ser escalado horizontalmente (múltiplas réplicas do mesmo `Deployment`) sem alteração de código, já que o RabbitMQ distribui as mensagens entre os consumidores conectados à mesma fila;
- Picos de upload não derrubam o sistema: o `video-upload-service` apenas enfileira o evento e retorna rapidamente ao usuário, enquanto o processamento pesado (`ffmpeg`) ocorre de forma assíncrona no `video-processing-service`;
- Falhas de processamento acionam a fila `video-events` com routing key `video.failed`, disparando tanto a atualização de status (`FAILED`) quanto a notificação por e-mail ao usuário.

---

## 4. Alternativas Rejeitadas

### 4.1 Comunicação síncrona (REST) entre todos os microsserviços
- Simples de implementar, mas acoplaria os serviços — uma indisponibilidade do `video-status-service`, por exemplo, poderia bloquear o fluxo de upload;
- Não atenderia ao requisito de "não perder uma requisição" em caso de pico ou indisponibilidade temporária de um serviço consumidor.

### 4.2 Um único monólito para todo o fluxo
- Mais simples de desenvolver inicialmente;
- Rejeitado — o desafio exige explicitamente uma arquitetura de microsserviços escalável e desacoplada.

### 4.3 Amazon SQS (em vez de RabbitMQ)
- Válido segundo o enunciado do desafio ("RabbitMQ, Amazon SQS ou similar");
- Rejeitado no cenário atual por não haver conta AWS ativa — RabbitMQ local atende ao mesmo propósito sem dependência de nuvem (ver RFC-003).

---

## 5. Consequências

### Positivas
- Processamento assíncrono e desacoplado atende aos requisitos de escalabilidade e resiliência a picos;
- Cada microsserviço pode evoluir e escalar independentemente;
- DLQs garantem rastreabilidade de mensagens com falha, sem perda silenciosa de dados.

### Negativas / Riscos
- Maior complexidade operacional (múltiplas filas, DLQs, monitoramento) comparado a uma solução síncrona simples;
- Consistência eventual: o status do vídeo pode levar alguns segundos para refletir o resultado real do processamento;
- `video-processing-service` provisiona um banco (`video_processing_db`) sem uso identificado — acompanhar em revisões futuras (ver ADR-004).

---

## 6. Referências

- ADR-001 (`auth`) — Autenticação JWT via Spring Security;
- ADR-003 — Ingress NGINX local;
- ADR-004 — PostgreSQL local por microsserviço;
- ADR-005 — Padronização de nomenclatura de filas RabbitMQ;
- `docs/diagrams/architecture-overview.png`, `docs/diagrams/process-flow.png`, `docs/diagrams/rabbitmq-topology.png` (versões vetoriais `.svg` no mesmo diretório);
- `docs/requirements/POSTECH - SOAT - Fase 5 - Hacka.txt` (workspace raiz).
