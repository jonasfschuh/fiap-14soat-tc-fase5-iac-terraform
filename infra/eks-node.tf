resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group-${var.project_identifier}"
  node_role_arn   = data.aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.default_vpc_subnets.ids

  instance_types = var.eks_node_instance_types
  disk_size      = var.eks_node_disk_size

  scaling_config {
    desired_size = var.eks_node_scaling_desired_size
    max_size     = var.eks_node_scaling_max_size
    min_size     = var.eks_node_scaling_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name              = "EKS Node Group ${var.project_name}"
    ProjectIdentifier = var.project_identifier
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}