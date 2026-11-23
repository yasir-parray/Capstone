terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "project_11" {
  bucket_prefix = "project-11-"
}

resource "aws_s3_bucket_public_access_block" "project_11" {
  bucket = aws_s3_bucket.project_11.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
