data "aws_caller_identity" "current" {}

locals {
  # EKS access entry exige principal IAM estavel (role/user), nao ARN STS assumed-role.
  caller_iam_principal_arn = startswith(data.aws_caller_identity.current.arn, "arn:aws:sts::") ? format(
    "arn:aws:iam::%s:role/%s",
    element(split(":", data.aws_caller_identity.current.arn), 4),
    element(split("/", data.aws_caller_identity.current.arn), 1)
  ) : data.aws_caller_identity.current.arn

  ci_access_principal_arn = length(trimspace(var.eks_ci_access_principal_arn)) > 0 ? trimspace(var.eks_ci_access_principal_arn) : local.caller_iam_principal_arn

  should_create_ci_access_entry = var.enable_eks_ci_access_entry && local.ci_access_principal_arn != data.aws_iam_role.eks_cluster_role.arn
}

resource "aws_eks_access_entry" "ci_principal" {
  count = local.should_create_ci_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = local.ci_access_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "ci_cluster_admin" {
  count = local.should_create_ci_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = aws_eks_access_entry.ci_principal[0].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
