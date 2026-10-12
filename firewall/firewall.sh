#!/bin/sh
# =====================================================================
#  Firewall da Ouvidoria Municipal - script de inicialização
#  Carrega as regras iptables automaticamente na subida do container.
# =====================================================================
set -e

# --- Endereçamento (igual ao docker-compose.yml) ---------------------
REDE_INTERNET="203.0.113.0/24"
REDE_LAN="10.10.10.0/24"
REDE_DMZ="10.10.20.0/24"
IP_PUBLICO_FW="203.0.113.254"   # "IP público" do firewall
SISTEMA="10.10.10.20"           # Sistema interno da ouvidoria (LAN)
WEB="10.10.20.10"               # Apache + PHP (portal do cidadão)
DB="10.10.20.20"                # MySQL
PMA="10.10.20.30"               # phpMyAdmin

# --- 1. Descobrir as interfaces pelo IP ------------------------------
# O Docker não garante a ordem eth0/eth1/eth2, então procuramos
# qual interface recebeu o IP de cada rede.
iface() { ip -o -4 addr show | awk -v p="$1" 'index($4, p) == 1 {print $2}'; }
NET=$(iface "203.0.113.")
LAN=$(iface "10.10.10.")
DMZ=$(iface "10.10.20.")

if [ -z "$NET" ] || [ -z "$LAN" ] || [ -z "$DMZ" ]; then
  echo "ERRO: interfaces nao encontradas (NET=$NET LAN=$LAN DMZ=$DMZ)"
  exit 1
fi
echo "Interfaces: INTERNET=$NET  LAN=$LAN  DMZ=$DMZ"

# --- 2. Roteamento (ip_forward) --------------------------------------
# Ligado pelo docker-compose (sysctls). Aqui apenas conferimos.
echo "ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
  echo "ERRO: ip_forward desligado. Verifique 'sysctls' no docker-compose.yml"
  exit 1
fi

# --- 3. Limpar regras antigas (flush) e zerar contadores -------------
iptables -F
iptables -t nat -F
iptables -X
iptables -Z

# --- 4. Política padrão: tudo bloqueado (Default DROP) ---------------
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# --- 5. INPUT: proteção do próprio firewall --------------------------
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP
# Somente a LAN pode pingar o gateway (diagnóstico)
iptables -A INPUT -i "$LAN" -s "$REDE_LAN" -p icmp --icmp-type echo-request -j ACCEPT

# --- 6. FORWARD: tráfego que atravessa o firewall --------------------
# Regra de ouro stateful: respostas de conexões já aceitas
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state INVALID -j DROP

# R1 - Cidadão (Internet) -> Portal web (porta 80, após o DNAT)
iptables -A FORWARD -i "$NET" -o "$DMZ" -p tcp -d "$WEB" --dport 80 \
  -m state --state NEW -j ACCEPT

# R2 - Servidores da prefeitura (LAN) -> Portal web (porta 80)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$REDE_LAN" -p tcp -d "$WEB" --dport 80 \
  -m state --state NEW -j ACCEPT

# R3 - Equipe da ouvidoria (LAN) -> phpMyAdmin (porta 80)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$REDE_LAN" -p tcp -d "$PMA" --dport 80 \
  -m state --state NEW -j ACCEPT

# R4 - Sistema interno da ouvidoria (LAN) -> MySQL: único autorizado a gravar
iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$SISTEMA" -p tcp -d "$DB" --dport 3306 \
  -m state --state NEW -j ACCEPT

# R5 - Demais máquinas da LAN -> MySQL: BLOQUEADO (vem DEPOIS da R4)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -p tcp -d "$DB" --dport 3306 -j DROP

# R6 - Regra de ouro da DMZ: DMZ NUNCA inicia conexão para a LAN
iptables -A FORWARD -i "$DMZ" -o "$LAN" -m state --state NEW -j DROP

# Todo o resto é descartado pela política padrão (FORWARD DROP).

# --- 7. NAT ----------------------------------------------------------
# DNAT (port forwarding): IP público :80 -> servidor web na DMZ
iptables -t nat -A PREROUTING -i "$NET" -d "$IP_PUBLICO_FW" -p tcp --dport 80 \
  -j DNAT --to-destination "$WEB:80"

# MASQUERADE na saída para a DMZ: os servidores respondem ao firewall,
# garantindo que a volta também passe por ele (sem mexer nas imagens oficiais).
# Efeito: o MySQL vê as conexões do sistema interno vindo de 10.10.20.254.
iptables -t nat -A POSTROUTING -o "$DMZ" -j MASQUERADE

# --- 8. Exibir as regras carregadas ----------------------------------
echo "================ REGRAS CARREGADAS (filter) ================"
iptables -L -n -v --line-numbers
echo "================ REGRAS CARREGADAS (nat) ==================="
iptables -t nat -L -n -v --line-numbers
echo "Firewall ativo."

# Mantém o container em execução
exec tail -f /dev/null
