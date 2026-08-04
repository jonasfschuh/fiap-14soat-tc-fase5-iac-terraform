data "aws_iam_role" "eks_cluster_role" {
  name = var.eks_cluster_role_name
}

data "aws_iam_role" "eks_node_role" {
  name = var.eks_node_role_name
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # EKS no us-east-1 nao aceita control plane na AZ 1e no Learner Lab.
  filter {
    name   = "availability-zone"
    values = var.eks_supported_control_plane_azs
  }
}