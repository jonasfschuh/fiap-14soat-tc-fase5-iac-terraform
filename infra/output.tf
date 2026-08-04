output "vpc_principal_cidr" {
  description = "Bloco CIDR da VPC em uso"
  value       = data.aws_vpc.default.cidr_block
}

output "vpc_principal_id" {
  description = "ID da VPC em uso"
  value       = data.aws_vpc.default.id
}

output "subnet_publica_ids" {
  description = "IDs das subnets em uso pelo EKS"
  value       = data.aws_subnets.default_vpc_subnets.ids
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.eks_cluster.name
}

# ─── NLB outputs ──────────────────────────────────────────────────────────────

output "nlb_dns_name" {
  description = "DNS do Network Load Balancer — usar como MERCADOPAGO_NOTIFICATION_URL base e AUTH_LAMBDA_URL"
  value       = aws_lb.eks_nlb.dns_name
}

output "nlb_arn" {
  description = "ARN do Network Load Balancer"
  value       = aws_lb.eks_nlb.arn
}

output "nlb_listener_arn" {
  description = "ARN do listener do Network Load Balancer (service-order, porta 80)"
  value       = aws_lb_listener.eks_listener.arn
}

output "nlb_ms_listener_arns" {
  description = "ARNs dos listeners NLB por MS (customer, vehicle, service, stocks, billing, purchase)"
  value = {
    for ms, _ in local.ms_ports :
    ms => aws_lb_listener.ms_listener[ms].arn
  }
}

# =============================================================================
# RDS PostgreSQL Compartilhado
# =============================================================================

output "rds_endpoint" {
  description = "Endpoint da instancia RDS compartilhada (host:port)"
  value       = aws_db_instance.postgres_shared.endpoint
}

output "rds_host" {
  description = "Hostname da instancia RDS (sem porta)"
  value       = split(":", aws_db_instance.postgres_shared.endpoint)[0]
}

output "rds_port" {
  description = "Porta da instancia RDS"
  value       = aws_db_instance.postgres_shared.port
}

output "rds_master_username" {
  description = "Username master do banco compartilhado"
  value       = aws_db_instance.postgres_shared.username
  sensitive   = true
}

