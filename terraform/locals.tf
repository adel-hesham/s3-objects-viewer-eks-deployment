locals {
  # Common tags applied to everything
  common_tags = {
    Environment = var.environment
    Project     = var.cluster_name
    ManagedBy   = "Terraform"
  }

  # Availability zones — fetched dynamically, don't hardcode
  azs = data.aws_availability_zones.available.names

  # Public subnet CIDRs — one per AZ
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1), # 10.0.1.0/24
    cidrsubnet(var.vpc_cidr, 8, 2), # 10.0.2.0/24
  ]

  # Private subnet CIDRs — one per AZ
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 10), # 10.0.10.0/24
    cidrsubnet(var.vpc_cidr, 8, 20), # 10.0.20.0/24
  ]
  oidc_host = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}