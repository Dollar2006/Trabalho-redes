#!/usr/bin/env bash
# Gera o arquivo .conf de um cliente WireGuard e registra o peer no servidor.
# Uso: ./vpn/gerar-config.sh <ip_publico_vpn> <chave_ssh_privada> <nome_cliente> <final_ip>
# Ex.: ./vpn/gerar-config.sh 3.90.10.20 ~/.ssh/id_ed25519 meu-notebook 2   -> 10.8.0.2
# Requer: ssh (Linux, macOS, WSL ou Git Bash). As chaves são geradas no servidor.
set -euo pipefail

VPN_IP="${1:?ip publico da VPN}"
KEY="${2:?chave ssh privada}"
NOME="${3:?nome do cliente}"
FINAL="${4:?final do ip (2-254)}"
VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"

CLIENT_IP="10.8.0.${FINAL}"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@${VPN_IP}")

SERVER_PUB=$("${SSH[@]}" "cat /etc/wireguard/server_public.key")
read -r PRIV PUB < <("${SSH[@]}" 'p=$(wg genkey); echo "$p $(echo "$p" | wg pubkey)"')

# registra o peer (ativo agora e persistido no wg0.conf)
"${SSH[@]}" "sudo wg set wg0 peer '$PUB' allowed-ips '${CLIENT_IP}/32' && \
  printf '\n[Peer]\n# %s\nPublicKey = %s\nAllowedIPs = %s/32\n' '$NOME' '$PUB' '$CLIENT_IP' | sudo tee -a /etc/wireguard/wg0.conf >/dev/null"

DIR="$(dirname "$0")/clientes"
mkdir -p "$DIR"
OUT="$DIR/${NOME}.conf"
umask 077
cat > "$OUT" <<CONF
[Interface]
PrivateKey = ${PRIV}
Address = ${CLIENT_IP}/32

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${VPN_IP}:51820
AllowedIPs = ${VPC_CIDR}, 10.8.0.0/24
PersistentKeepalive = 25
CONF

echo "Config gerada em: $OUT"
echo "Importe no app WireGuard. Depois: ssh -i $KEY ubuntu@<ip_privado_da_app_ou_db>"
