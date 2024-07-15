provider "aws" {
  region = "ap-south-1"
}

# Include VPC configuration
module "vpc" {
  source = "./modules/eks"
}

# Include EKS configuration
module "eks" {
  source = "./modules/eks"
}
