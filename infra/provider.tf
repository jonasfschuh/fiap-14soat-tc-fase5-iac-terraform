# Configura o Terraform para usar os providers do Kubernetes e do Helm localmente.
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Usa o kubeconfig local apontando para o contexto configurado no Docker Desktop.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kube_context
}

# Usa o mesmo kubeconfig local para instalar charts Helm no cluster.
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.kube_context
  }
}
