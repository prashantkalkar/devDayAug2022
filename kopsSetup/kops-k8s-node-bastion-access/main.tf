terraform {
  required_version = "= 1.2.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.27.0"
    }
  }

  backend "s3" {
    key = "kops-bastion-access-sg.tfstate"
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

resource "aws_security_group_rule" "allow_access_to_nodeport_portrange_from_bastion" {
  # Node Port Range: https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
  security_group_id        = var.node_security_group_id
  from_port                = 30000
  protocol                 = "TCP"
  to_port                  = 32767
  type                     = "ingress"
  source_security_group_id = var.bastion_security_group_id
}

variable "created_by_tag" {
}

variable "node_security_group_id" {
  description = "Security group ip attached to k8s worker nodes created by kops"
}

variable "bastion_security_group_id" {
  description = "Security group ip attached to bastion nodes created by kops"
}