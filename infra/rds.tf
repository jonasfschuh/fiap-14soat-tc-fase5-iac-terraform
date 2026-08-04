# =============================================================================
# RDS PostgreSQL Compartilhado — 1 instancia, 6 bancos (customer, vehicle,
# service, stocks, billing, purchase_order)
#
# Configuracoes minimas para reduzir custo no AWS Academy ($50 de credito):
#   - db.t3.micro       = ~$0.017/hr = ~$12/mes
#   - 20GB GP2          = ~$2.30/mes
#   - TOTAL             = ~$14.30/mes  (vs ~$73/mes com 6 instancias separadas)
#
# Cada MS cria seu proprio banco via deploy_infra.yaml (psql CREATE DATABASE).
# =============================================================================

resource "aws_security_group" "rds_shared_sg" {
  name        = "raceforce-rds-shared-sg"
  description = "SG da instancia RDS compartilhada - acesso interno (pods EKS) e externo (CI/CD)"
  vpc_id      = data.aws_vpc.default.id

  # Pods EKS dentro da VPC
  ingress {
    description = "PostgreSQL - acesso interno da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # GitHub Actions precisa criar os bancos (CREATE DATABASE) via psql
  ingress {
    description = "PostgreSQL - acesso externo para pipeline CI/CD (GitHub Actions)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "raceforce-rds-shared-sg"
  }
}

resource "aws_db_subnet_group" "rds_shared_subnet_group" {
  name       = "raceforce-rds-shared-subnet-group"
  subnet_ids = data.aws_subnets.default_vpc_subnets.ids

  tags = {
    Name = "raceforce-rds-shared-subnet-group"
  }
}

resource "aws_db_instance" "postgres_shared" {
  identifier     = var.rds_identifier
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  # Storage — minimo, sem autoscaling
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp2"
  storage_encrypted     = false

  # Banco inicial (os outros 5 sao criados pelo deploy_infra.yaml de cada MS)
  db_name  = "postgres"
  username = var.rds_master_username
  password = var.rds_master_password
  port     = 5432

  # Rede
  db_subnet_group_name   = aws_db_subnet_group.rds_shared_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_shared_sg.id]
  publicly_accessible    = true

  # Single-AZ, sem replicas
  multi_az = false

  # Backup desabilitado — economiza storage e custo
  backup_retention_period = 0
  copy_tags_to_snapshot   = false
  skip_final_snapshot     = true
  deletion_protection     = false

  # Monitoramento desabilitado — economiza custo
  monitoring_interval          = 0
  performance_insights_enabled = false

  # Logs desabilitados — economiza custo
  enabled_cloudwatch_logs_exports = []

  # Manutencao desabilitada — ambiente de laboratorio
  auto_minor_version_upgrade = false
  apply_immediately          = true

  tags = {
    Name = var.rds_identifier
  }
}
