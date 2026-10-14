FROM alpine:3.20
RUN apk add --no-cache iptables iproute2
COPY firewall.sh /firewall.sh
# Remove CRLF caso o arquivo tenha sido salvo no Windows
RUN sed -i 's/\r$//' /firewall.sh
ENTRYPOINT ["/bin/sh", "/firewall.sh"]
