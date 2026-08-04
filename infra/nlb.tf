# Data source para pegar CIDR da VPC default
# A VPC default e carregada em datasource.tf

data "aws_vpc" "main" {
  id = data.aws_vpc.default.id
}

# Security Group para o NLB
resource "aws_security_group" "nlb_sg" {
  name        = "${var.project_identifier}-nlb-sg"
  description = "Security group para Network Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP de qualquer lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS de qualquer lugar"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePorts dos MSs (acesso via VPC Link interno)"
    from_port   = 30081
    to_port     = 30086
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permitir todo trafego de saida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_identifier}-nlb-sg"
  }
}

locals {
  # Limita o prefixo para manter nomes do ELB/TG abaixo de 32 caracteres.
  nlb_name_prefix = substr(var.project_identifier, 0, 20)
}

# Network Load Balancer para o EKS
resource "aws_lb" "eks_nlb" {
  name = "${local.nlb_name_prefix}-nlb"
  # Fase 1: endpoint externo oficial e o API Gateway; este NLB permanece interno para VPC Link.
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = data.aws_subnets.default_vpc_subnets.ids
  security_groups                  = [aws_security_group.nlb_sg.id]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  tags = {
    Name = "${var.project_identifier}-eks-nlb"
  }
}

# Target Group para o NLB (HTTP na porta 80)
resource "aws_lb_target_group" "eks_tg" {
  name        = "${local.nlb_name_prefix}-tg"
  port        = 30080
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = "30080"
  }

  tags = {
    Name = "${var.project_identifier}-eks-tg"
  }
}

# Listener do NLB na porta 80
resource "aws_lb_listener" "eks_listener" {
  load_balancer_arn = aws_lb.eks_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_tg.arn
  }
}

# Anexa o Auto Scaling Group do EKS ao Target Group do NLB
resource "aws_autoscaling_attachment" "eks_asg_attachment" {
  autoscaling_group_name = tolist(aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups)[0].name
  lb_target_group_arn    = aws_lb_target_group.eks_tg.arn

  depends_on = [aws_eks_node_group.eks_node_group]
}

# Regra para permitir que o NLB acesse os nos do EKS na porta do NodePort
resource "aws_security_group_rule" "allow_nlb_to_eks_nodes" {
  type        = "ingress"
  description = "Permitir trafego do NLB para os nos do EKS na porta 30080"
  from_port   = 30080
  to_port     = 30080
  protocol    = "tcp"

  source_security_group_id = aws_security_group.nlb_sg.id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id

  depends_on = [aws_eks_cluster.eks_cluster]
}

# Regra adicional para permitir que toda a VPC acesse NodePort nos nos EKS
resource "aws_security_group_rule" "allow_vpc_to_cluster_nodeport" {
  type              = "ingress"
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.main.cidr_block]
  security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  description       = "Allow VPC traffic to reach nodePort 30080 on EKS cluster nodes"

  depends_on = [aws_eks_cluster.eks_cluster]
}

# Regra para NLB acessar todos os NodePorts dos MSs (30081-30086)
resource "aws_security_group_rule" "allow_nlb_to_eks_nodes_ms_range" {
  type                     = "ingress"
  description              = "Permitir trafego do NLB para os nos do EKS nas portas 30081-30086 (MSs)"
  from_port                = 30081
  to_port                  = 30086
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nlb_sg.id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_vpc_to_cluster_nodeport_ms_range" {
  type              = "ingress"
  from_port         = 30081
  to_port           = 30086
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.main.cidr_block]
  security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  description       = "Allow VPC traffic to reach NodePorts 30081-30086 on EKS cluster nodes (all MSs)"
  depends_on        = [aws_eks_cluster.eks_cluster]
}

# =============================================================================
# Per-MS Target Groups, Listeners e ASG Attachments
# customer:30081 | billing:30082 | vehicle:30083 | service:30084
# stocks:30085   | purchase-order:30086
# =============================================================================

locals {
  ms_ports = {
    customer  = 30081
    billing   = 30082
    vehicle   = 30083
    service   = 30084
    stocks    = 30085
    purchase  = 30086
  }
}

resource "aws_lb_target_group" "ms_tg" {
  for_each    = local.ms_ports
  name        = "${local.nlb_name_prefix}-${each.key}-tg"
  port        = each.value
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = tostring(each.value)
  }

  tags = { Name = "${var.project_identifier}-${each.key}-tg" }
}

resource "aws_lb_listener" "ms_listener" {
  for_each          = local.ms_ports
  load_balancer_arn = aws_lb.eks_nlb.arn
  port              = tostring(each.value)
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_tg[each.key].arn
  }
}

resource "aws_autoscaling_attachment" "ms_asg_attachment" {
  for_each               = local.ms_ports
  autoscaling_group_name = tolist(aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups)[0].name
  lb_target_group_arn    = aws_lb_target_group.ms_tg[each.key].arn
  depends_on             = [aws_eks_node_group.eks_node_group]
}