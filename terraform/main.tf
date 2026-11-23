terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = var.project }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# AMI Ubuntu 24.04 mais recente (via SSM público da Canonical)
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  vpn_network   = "10.8.0.0/24"
  vpn_server_ip = "10.8.0.1"
}
