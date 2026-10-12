FROM alpine:3.20
RUN apk add --no-cache iptables iproute2
# O script de regras é montado como volume pelo docker-compose
ENTRYPOINT ["/bin/sh", "/firewall.sh"]
