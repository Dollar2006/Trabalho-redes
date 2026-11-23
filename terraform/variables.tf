variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "estoque"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_cidr" {
  type        = string
  description = "Seu IP público em /32 (ex.: curl ifconfig.me). Só ele acessa o SSH da VPN."
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "repo_url" {
  type        = string
  description = "URL HTTPS do repositório GitHub (público) que as instâncias vão clonar."
}

variable "db_password" {
  type      = string
  sensitive = true
}


variable "instance_type" {
  type    = string
  default = "t3.micro"
}
