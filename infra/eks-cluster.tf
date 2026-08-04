resource "aws_eks_cluster" "eks_cluster" {
  version  = "1.33"
  name     = var.eks_cluster_name
  role_arn = data.aws_iam_role.eks_cluster_role.arn

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = data.aws_subnets.default_vpc_subnets.ids
  }

  tags = {
    Name              = "EKS Cluster ${var.project_name}"
    ProjectIdentifier = var.project_identifier
  }
}