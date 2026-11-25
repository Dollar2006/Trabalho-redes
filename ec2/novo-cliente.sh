#!/usr/bin/env bash
# Cria um cliente WireGuard (notebook, celular...) e registra no servidor.
# Uso: sudo bash ec2/novo-cliente.sh <nome> <final_do_ip 2-254> [ip_publico]
# O IP publico e descoberto sozinho (metadados da EC2); informe so se falhar.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Rode com sudo: sudo bash ec2/novo-cliente.sh <nome> <final_ip>"
  exit 1
fi

NOME="${1:?nome do cliente, ex.: notebook}"
FINAL="${2:?final do IP na VPN (2-254)}"
PUB_IP="${3:-}"
USER_NAME="${SUDO_USER:-ubuntu}"
CLIENT_IP="10.8.0.${FINAL}"

if [ -z "$PUB_IP" ]; then
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
  PUB_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
fi
if [ -z "$PUB_IP" ]; then
  echo "Nao consegui descobrir o IP publico. Informe como 3o argumento."
  exit 1
fi

if grep -q "AllowedIPs = ${CLIENT_IP}/32" /etc/wireguard/wg0.conf; then
  echo "O IP ${CLIENT_IP} ja esta em uso. Escolha outro final."
  exit 1
fi

PRIV=$(wg genkey)
PUB=$(echo "$PRIV" | wg pubkey)

# ativo agora e gravado para o proximo boot
wg set wg0 peer "$PUB" allowed-ips "${CLIENT_IP}/32"
printf '\n[Peer]\n# %s\nPublicKey = %s\nAllowedIPs = %s/32\n' "$NOME" "$PUB" "$CLIENT_IP" >> /etc/wireguard/wg0.conf

OUT_DIR="/home/${USER_NAME}/clientes"
mkdir -p "$OUT_DIR"
OUT="${OUT_DIR}/${NOME}.conf"
(
  umask 077
  cat > "$OUT" <<CLEOF
[Interface]
PrivateKey = ${PRIV}
Address = ${CLIENT_IP}/32

[Peer]
PublicKey = $(cat /etc/wireguard/server.pub)
Endpoint = ${PUB_IP}:51820
AllowedIPs = 10.8.0.1/32
PersistentKeepalive = 25
CLEOF
)
chown -R "$USER_NAME": "$OUT_DIR"

echo "Cliente criado: $OUT (IP na VPN: ${CLIENT_IP}, endpoint: ${PUB_IP}:51820)"
echo "Copie para o seu computador, por exemplo: scp ubuntu@${PUB_IP}:clientes/${NOME}.conf ."
