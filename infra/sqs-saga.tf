# =============================================================================
# SQS Queues — SAGA Orchestration (service-order → purchase-order / stocks / billing)
# ADR-013 v2.0: ServiceOrderSagaOrchestrator (Model B — Internal Orchestrator)
# =============================================================================

locals {
  saga_queues = [
    "so-commands-purchase-order",
    "so-commands-stocks",
    "so-commands-billing",
    "so-replies"
  ]

  domain_event_queues = [
    "payment-confirmed",
    "service-order-completed",
    "purchase-order-events"
  ]
}

# ─── Dead Letter Queues — SAGA ────────────────────────────────────────────────

resource "aws_sqs_queue" "saga_dlq" {
  for_each = toset(local.saga_queues)

  name                      = "${each.value}-dlq"
  message_retention_seconds = 604800 # 7 days — for manual inspection and re-processing

  tags = {
    Project      = "fiap-14soat-tc-fase5"
    MicroService = "saga-orchestration"
    Type         = "dlq"
  }
}

# ─── Main SAGA Queues ─────────────────────────────────────────────────────────

resource "aws_sqs_queue" "saga" {
  for_each = toset(local.saga_queues)

  name                       = each.value
  visibility_timeout_seconds = 30    # Grace period for processing before re-delivery
  message_retention_seconds  = 86400 # 24 hours

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.saga_dlq[each.key].arn
    maxReceiveCount     = 3 # 3 delivery attempts before going to DLQ
  })

  tags = {
    Project      = "fiap-14soat-tc-fase5"
    MicroService = "saga-orchestration"
    Type         = "main"
  }
}

# ─── Dead Letter Queues — Domain Events ──────────────────────────────────────

resource "aws_sqs_queue" "domain_event_dlq" {
  for_each = toset(local.domain_event_queues)

  name                      = "${each.value}-dlq"
  message_retention_seconds = 604800

  tags = {
    Project      = "fiap-14soat-tc-fase5"
    MicroService = "domain-events"
    Type         = "dlq"
  }
}

# ─── Domain Event Queues ──────────────────────────────────────────────────────

resource "aws_sqs_queue" "domain_event" {
  for_each = toset(local.domain_event_queues)

  name                       = each.value
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.domain_event_dlq[each.key].arn
    maxReceiveCount     = 3
  })

  tags = {
    Project      = "fiap-14soat-tc-fase5"
    MicroService = "domain-events"
    Type         = "main"
  }
}

# ─── Outputs ──────────────────────────────────────────────────────────────────

output "saga_queue_arns" {
  description = "ARNs of all SAGA SQS queues"
  value       = { for k, q in aws_sqs_queue.saga : k => q.arn }
}

output "saga_queue_urls" {
  description = "URLs of all SAGA SQS queues"
  value       = { for k, q in aws_sqs_queue.saga : k => q.url }
}

output "saga_dlq_arns" {
  description = "ARNs of all SAGA Dead Letter Queues"
  value       = { for k, q in aws_sqs_queue.saga_dlq : k => q.arn }
}

output "domain_event_queue_urls" {
  description = "URLs of all Domain Event SQS queues"
  value       = { for k, q in aws_sqs_queue.domain_event : k => q.url }
}

output "domain_event_queue_arns" {
  description = "ARNs of all Domain Event SQS queues"
  value       = { for k, q in aws_sqs_queue.domain_event : k => q.arn }
}

