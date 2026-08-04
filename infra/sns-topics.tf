# =============================================================================
# SNS Topics — Domain Events (purchase-order lifecycle)
# Consumed by: service-order and future subscribers
# =============================================================================

locals {
  purchase_order_topics = [
    "purchase-order-created",
    "purchase-order-completed",
    "purchase-order-cancelled"
  ]
}

resource "aws_sns_topic" "purchase_order" {
  for_each = toset(local.purchase_order_topics)

  name = each.value

  tags = {
    Project      = "FIAP-14SOAT-TC-FASE4"
    MicroService = "purchase-order"
    Type         = "sns-topic"
  }
}

# ─── Outputs ──────────────────────────────────────────────────────────────────

output "sns_topic_arns" {
  description = "ARNs of all purchase-order SNS topics"
  value       = { for k, t in aws_sns_topic.purchase_order : k => t.arn }
}

output "sns_topic_urls" {
  description = "ARNs (used as identifiers) of all purchase-order SNS topics"
  value       = { for k, t in aws_sns_topic.purchase_order : k => t.arn }
}
