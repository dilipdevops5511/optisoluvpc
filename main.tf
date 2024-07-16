# Define the AWS provider
provider "aws" {
  region = "us-east-1"  # Replace with your desired AWS region
}

# Define variables
variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "cluster_name" {
  default = "my-eks-cluster"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

# Create Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create IAM Role for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM policies to EKS cluster role (example policies)
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids          = [aws_subnet.public[0].id, aws_subnet.public[1].id, aws_subnet.public[2].id]
    security_group_ids  = [aws_security_group.eks_cluster_sg.id]
    endpoint_public_access = true
    endpoint_private_access = true
  }
}

# Create IAM Role for EKS nodes
resource "aws_iam_role" "eks_node_role" {
  name               = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM policies to EKS node role (example policies)
resource "aws_iam_role_policy_attachment" "eks_node_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Create Security Group for EKS cluster
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# Create EKS node group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public[0].id, aws_subnet.public[1].id, aws_subnet.public[2].id]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
