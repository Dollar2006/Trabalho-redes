#!/usr/bin/env bash
# Prepara uma EC2 Ubuntu 24.04 para rodar o projeto:
# Docker, Terraform e WireGuard (servidor da VPN, 10.8.0.1).
# Uso (dentro da pasta do projeto, na EC2): sudo bash ec2/setup-ec2.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Rode com sudo: sudo bash ec2/setup-ec2.sh"
  exit 1
fi

USER_NAME="${SUDO_USER:-ubuntu}"
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEBIAN_FRONTEND=noninteractive

echo "==> Instalando pacotes"
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release unzip openssl \
  docker.io docker-compose-v2 wireguard qrencode

echo "==> Instalando Terraform"
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -y
  apt-get install -y terraform
fi

echo "==> Docker"
systemctl enable --now docker
usermod -aG docker "$USER_NAME"

echo "==> WireGuard (servidor 10.8.0.1)"
install -d -m 700 /etc/wireguard
if [ ! -f /etc/wireguard/server.key ]; then
  (
    umask 077
    wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
    cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server.key)
WGEOF
  )
fi
systemctl enable --now wg-quick@wg0

echo "==> Senha do banco (terraform-local/terraform.tfvars)"
TF_DIR="$PROJ_DIR/terraform-local"
if [ ! -d "$TF_DIR" ]; then
  echo "ERRO: pasta terraform-local nao encontrada em $PROJ_DIR"
  exit 1
fi
if [ ! -f "$TF_DIR/terraform.tfvars" ]; then
  echo "db_password = \"$(openssl rand -hex 16)\"" > "$TF_DIR/terraform.tfvars"
fi
chown -R "$USER_NAME": "$PROJ_DIR"

echo
echo "Pronto. Saia (exit) e entre de novo no SSH, para o grupo docker valer. Depois:"
echo "  cd $TF_DIR && terraform init && terraform apply"
