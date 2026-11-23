terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
locals {
  project_name = "yasir_project_03"

  common_tags = {
    Project   = local.project_name
    ManagedBy = "Terraform"
  }
}

provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_vpc" "project" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "project" {
  vpc_id = aws_vpc.project.id

  tags = {
    Name = "${local.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project.id
  }

  tags = {
    Name = "${local.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "instance" {
  name        = "${local.project_name}-sg"
  description = "No inbound access; outbound access for Systems Manager"
  vpc_id      = aws_vpc.project.id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name}-sg"
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${local.project_name}-ssm-role"

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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.project_name}-instance-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "project" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = true


  monitoring = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }


  root_block_device {
    encrypted             = true
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }


  tags = {
    Name = "${local.project_name}-ec2"
  }

  user_data_replace_on_change = true

  user_data = <<-EOF
#!/bin/bash
set -e

cat >/usr/local/bin/project3-cpu-load.sh <<'SCRIPT'
#!/bin/bash
yes >/dev/null &
yes >/dev/null &
wait
SCRIPT
chmod 0755 /usr/local/bin/project3-cpu-load.sh

cat >/etc/systemd/system/project3-cpu-load.service <<'UNIT'
[Unit]
Description=Short Project 3 CPU alarm test

[Service]
Type=simple
ExecStart=/usr/local/bin/project3-cpu-load.sh
RuntimeMaxSec=240
UNIT

cat >/etc/systemd/system/project3-cpu-load.timer <<'UNIT'
[Unit]
Description=Start the Project 3 CPU alarm test

[Timer]
OnActiveSec=180s
Unit=project3-cpu-load.service

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now project3-cpu-load.timer
EOF

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_route_table_association.public
  ]
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.project_name}-cpu-high"
  alarm_description   = "Triggers when EC2 average CPU exceeds 70 percent."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.project.id
  }
}
