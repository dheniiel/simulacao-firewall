FROM php:8.3-apache
# iproute2: criar a rota para a DMZ via firewall | pdo_mysql: acesso ao MySQL
RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 \
 && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-install pdo_mysql
COPY src/ /var/www/html/
# Rota para a DMZ passando pelo firewall e, em seguida, inicia o Apache
CMD ["sh", "-c", "ip route replace 10.10.20.0/24 via 10.10.10.254 && exec apache2-foreground"]
