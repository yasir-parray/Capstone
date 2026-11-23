terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  common_tags = {
    Project = "Project_10"
    Purpose = "Internal DNS lab"
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.77.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "Project10-InternalDNS-VPC"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.77.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "Project10-InternalDNS-Subnet"
  })
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "Project10-InternalDNS-IGW"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "Project10-InternalDNS-Routes"
  })
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name_prefix = "p10-web-"
  description = "Project 10 web server"
  vpc_id      = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "Project10-Web-SG"
  })
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = aws_vpc.lab.cidr_block
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from inside the Project 10 VPC"
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "dns" {
  name_prefix = "p10-dns-"
  description = "Project 10 internal DNS server"
  vpc_id      = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "Project10-DNS-SG"
  })
}

resource "aws_vpc_security_group_ingress_rule" "dns_udp_from_web" {
  security_group_id            = aws_security_group.dns.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "udp"
  description                  = "DNS queries from the Project 10 web server"
}

resource "aws_vpc_security_group_ingress_rule" "dns_tcp_from_web" {
  security_group_id            = aws_security_group.dns.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "tcp"
  description                  = "DNS queries from the Project 10 web server"
}

resource "aws_vpc_security_group_egress_rule" "dns_outbound" {
  security_group_id = aws_security_group.dns.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "ec2_ssm" {
  name_prefix = "p10-dns-lab-ssm-"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name_prefix = "p10-dns-lab-ssm-"
  role        = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "dns" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  private_ip                  = "10.77.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.dns.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y bind bind-utils

    cat >/etc/named.conf <<'NAMEDCONF'
    options {
      directory "/var/named";
      listen-on port 53 { 127.0.0.1; 10.77.1.10; };
      listen-on-v6 { none; };
      allow-query { localhost; 10.77.0.0/16; };
      allow-recursion { localhost; 10.77.0.0/16; };
      forwarders { 169.254.169.253; };
      recursion yes;
      dnssec-validation auto;
    };
    zone "project10.test" IN {
      type master;
      file "project10.test.zone";
      allow-transfer { none; };
    };
    NAMEDCONF

    cat >/var/named/project10.test.zone <<'ZONE'
    $TTL 60
    @ IN SOA ns1.project10.test. hostmaster.project10.test. (
      2026112301 60 60 3600 60
    )
    @   IN NS ns1.project10.test.
    ns1 IN A 10.77.1.10
    web IN A 10.77.1.20
    ZONE

    chown root:named /var/named/project10.test.zone
    chmod 640 /var/named/project10.test.zone
    named-checkconf
    named-checkzone project10.test /var/named/project10.test.zone
    systemctl enable --now named
    systemctl enable --now amazon-ssm-agent
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Project10-DNS-Server"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_route.internet,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.dns_outbound,
    aws_vpc_security_group_egress_rule.web_outbound
  ]
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  private_ip                  = "10.77.1.20"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y httpd bind-utils

    cat >/var/www/html/index.html <<'HTML'
    <!doctype html>
    <html>
      <head><title>Project 10 DNS Lab</title></head>
      <body><h1>Project 10 web server</h1><p>Internal DNS lookup succeeded.</p></body>
    </html>
    HTML

    systemctl enable --now httpd
    systemctl enable --now amazon-ssm-agent
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Project10-Web-Server"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_route.internet,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.dns_outbound,
    aws_vpc_security_group_egress_rule.web_outbound
  ]
}

output "vpc_id" {
  value = aws_vpc.lab.id
}

output "dns_instance_id" {
  value = aws_instance.dns.id
}

output "dns_private_ip" {
  value = aws_instance.dns.private_ip
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}