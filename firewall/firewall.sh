#!/bin/sh
# =====================================================================
#  Firewall da Ouvidoria Municipal - carregado automaticamente na subida
#  Politica: tudo bloqueado (DROP) + liberacoes explicitas (R1..R6)
# =====================================================================
set -e

# --- Enderecamento (o mesmo do docker-compose.yml) -------------------
FW_NET="203.0.113.254"   # IP "publico" do firewall (Internet)
FW_LAN="10.10.10.254"    # IP do firewall na LAN (gateway dos clientes)
FW_DMZ="10.10.20.254"    # IP do firewall na DMZ
REDE_LAN="10.10.10.0/24"
SISTEMA="10.10.10.20"    # sistema interno (unico que pode gravar no banco)
WEB="10.10.20.10"        # portal do cidadao (DMZ)
DB="10.10.20.20"         # MySQL (DMZ)

# --- Descobre a interface de cada rede pelo IP -----------------------
# (o Docker nao garante a ordem eth0/eth1/eth2)
iface() { ip -o -4 addr show | awk -v ip="$1" 'index($4, ip "/") == 1 {print $2}'; }
NET=$(iface "$FW_NET"); LAN=$(iface "$FW_LAN"); DMZ=$(iface "$FW_DMZ")
if [ -z "$NET" ] || [ -z "$LAN" ] || [ -z "$DMZ" ]; then
  echo "ERRO: interfaces nao encontradas (NET=$NET LAN=$LAN DMZ=$DMZ)"; exit 1
fi
echo "Interfaces: INTERNET=$NET LAN=$LAN DMZ=$DMZ"
echo "ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"

# --- Limpa regras anteriores (so as nossas cadeias) -------------------
iptables -F; iptables -X; iptables -Z
iptables -t nat -F PREROUTING; iptables -t nat -F POSTROUTING

# --- Politica padrao: DROP -------------------------------------------
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# --- INPUT: protege o proprio firewall --------------------------------
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# R6 - So a LAN pode pingar o gateway (diagnostico)
iptables -A INPUT -i "$LAN" -s "$REDE_LAN" -p icmp --icmp-type echo-request -j ACCEPT

# --- NAT: o firewall "publica" os servicos da DMZ ---------------------
# Os clientes nunca falam com o IP da DMZ: falam com o IP do firewall na
# propria rede e o firewall encaminha (DNAT) - mas so se a FORWARD deixar.
iptables -t nat -A PREROUTING -i "$NET" -d "$FW_NET" -p tcp --dport 80   -j DNAT --to-destination "$WEB:80"
iptables -t nat -A PREROUTING -i "$LAN" -d "$FW_LAN" -p tcp --dport 80   -j DNAT --to-destination "$WEB:80"
iptables -t nat -A PREROUTING -i "$LAN" -d "$FW_LAN" -p tcp --dport 3306 -j DNAT --to-destination "$DB:3306"
# Os servidores da DMZ nao tem rota para outras redes: o MASQUERADE faz a
# resposta voltar pelo firewall. Efeito: a DMZ ve as conexoes vindo de 10.10.20.254.
iptables -t nat -A POSTROUTING -o "$DMZ" -j MASQUERADE

# --- FORWARD: trafego que atravessa o firewall ------------------------
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# R1 - Internet -> portal web (HTTP)
iptables -A FORWARD -i "$NET" -o "$DMZ" -d "$WEB" -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
# R2 - LAN -> portal web (HTTP)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$REDE_LAN" -d "$WEB" -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
# R3 - Sistema interno -> MySQL (unica origem autorizada)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -s "$SISTEMA" -d "$DB" -p tcp --dport 3306 -m conntrack --ctstate NEW -j ACCEPT
# R4 - Demais maquinas da LAN -> MySQL: bloqueado (precisa vir DEPOIS da R3)
iptables -A FORWARD -i "$LAN" -o "$DMZ" -d "$DB" -p tcp --dport 3306 -j DROP
# R5 - DMZ nunca inicia conexao para a LAN (contencao se a DMZ for invadida)
iptables -A FORWARD -i "$DMZ" -o "$LAN" -m conntrack --ctstate NEW -j DROP
# Todo o resto: politica padrao DROP.

echo "================ filter ================"; iptables -L -n -v --line-numbers
echo "================ nat ==================="; iptables -t nat -L PREROUTING -n -v --line-numbers
iptables -t nat -L POSTROUTING -n -v --line-numbers
echo "Firewall ativo."
exec tail -f /dev/null
