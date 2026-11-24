terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = {
      Project = "Project_14"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "project-14-yasir-eks"
  zones        = slice(sort(data.aws_availability_zones.available.names), 0, 2)
}

resource "aws_vpc" "project14" {
  cidr_block           = "10.77.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "project14-vpc"
  }
}

resource "aws_internet_gateway" "project14" {
  vpc_id = aws_vpc.project14.id

  tags = {
    Name = "project14-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = toset(local.zones)

  vpc_id                  = aws_vpc.project14.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(aws_vpc.project14.cidr_block, 4, index(local.zones, each.value))
  map_public_ip_on_launch = true

  tags = {
    Name                     = "project14-public-${each.value}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project14.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project14.id
  }

  tags = {
    Name = "project14-public-routes"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_iam_role" "cluster" {
  name_prefix = "project14-eks-cluster-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "project14" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.37"

  vpc_config {
    subnet_ids              = values(aws_subnet.public)[*].id
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_iam_role" "nodes" {
  name_prefix = "project14-eks-nodes-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  role       = aws_iam_role.nodes.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "project14" {
  cluster_name    = aws_eks_cluster.project14.name
  node_group_name = "project14-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = values(aws_subnet.public)[*].id
  instance_types  = ["t3.medium"]
  disk_size       = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes,
    aws_route_table_association.public
  ]
}

output "cluster_name" {
  value = aws_eks_cluster.project14.name
}

output "region" {
  value = "sa-east-1"
}
