terraform {
  backend "s3" {
    bucket = "fiap-14soat-fase5-jonasfschuh"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}

