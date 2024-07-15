provider "aws" {
  region = "ap-south-1"
}

# Include VPC configuration
module "vpc" {
  source = "./module/vpc"
}

# Include EKS configuration
module "eks" {
  source = "./module/eks"
}
