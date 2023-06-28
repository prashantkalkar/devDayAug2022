terraform {
  required_version = "= 1.2.7"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "= 4.27.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      created_by = var.created_by_tag
      usage = "k8sDevDayTalk2022"
    }
  }
}

resource "aws_s3_bucket" "kopsStateBucket" {
  bucket = var.tf_s3_bucket_name
  force_destroy = var.bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.kopsStateBucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.kopsStateBucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

variable "tf_s3_bucket_name" {
}

variable "created_by_tag" {
}

variable "bucket_force_destroy" {
  type = bool
  default = false
}