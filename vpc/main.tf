# Define the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Get the first 3 availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Define the public subnets
resource "aws_subnet" "public" {
  count                   = min(length(data.aws_availability_zones.available.names), 3)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Define the private subnets
resource "aws_subnet" "private" {
  count             = min(length(data.aws_availability_zones.available.names), 3)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Define the Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Define the public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = min(length(data.aws_availability_zones.available.names), 3)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Define Security Group for NodePort services
resource "aws_security_group" "nodeport_sg" {
  name        = "nodeport-security-group"
  description = "Security group for NodePort services"

  vpc_id = aws_vpc.main.id

  // Ingress rules for NodePort and additional ports
  ingress {
    description = "Allow inbound traffic for NodePort service"
    from_port   = 30500
    to_port     = 30500 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow access from anywhere (adjust as needed)
  }

  // Optionally, add more ingress rules for additional ports here if needed
  // ingress {
  //   description = "Allow inbound traffic for additional ports"
  //   from_port   = 80
  //   to_port     = 80
  //   protocol    = "tcp"
  //   cidr_blocks = ["0.0.0.0/0"]
  // }

  tags = {
    Name = "nodeport-security-group"
  }
}

# Output for VPC
output "vpc_id" {
  value = aws_vpc.main.id
}

# Output for public subnets
output "public_subnets" {
  value = aws_subnet.public.*.id
}
