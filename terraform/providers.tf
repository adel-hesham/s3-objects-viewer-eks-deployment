terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  # uncomment when you have an S3 backend ready
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "eks/terraform.tfstate"
  #   region = "us-east-1"
  # }
}



output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

provider "aws" {
  region = var.region
}

# Kubernetes and Helm providers need cluster credentials
# They can only be configured AFTER the cluster exists
# So we use data sources to get the endpoint and auth token

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", aws_eks_cluster.main.name,
      "--region", var.region
    ]
  }
}


provider "helm" {

}

provider "tls" {}

