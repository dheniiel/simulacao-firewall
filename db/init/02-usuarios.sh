#!/bin/bash
# Usuários do banco com o MENOR PRIVILÉGIO necessário para cada sistema.
#  - Portal do cidadão (DMZ 10.10.20.10): só leitura.
#  - phpMyAdmin (DMZ 10.10.20.30): só leitura (painel de visualização).
#  - Sistema interno (LAN 10.10.10.20): leitura e escrita. Por causa do
#    MASQUERADE do firewall, o MySQL enxerga essa conexão vindo do IP do
#    firewall na DMZ (10.10.20.254); quem garante que só o 10.10.10.20
#    chega aqui é a regra R4 do firewall.
mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE USER 'ouvidoria_leitura'@'10.10.20.10' IDENTIFIED BY '${DB_READ_PASSWORD}';
GRANT SELECT ON ouvidoria.manifestacoes TO 'ouvidoria_leitura'@'10.10.20.10';

CREATE USER 'ouvidoria_painel'@'10.10.20.30' IDENTIFIED BY '${DB_PAINEL_PASSWORD}';
GRANT SELECT ON ouvidoria.* TO 'ouvidoria_painel'@'10.10.20.30';

CREATE USER 'ouvidoria_sistema'@'10.10.20.254' IDENTIFIED BY '${DB_SISTEMA_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ouvidoria.manifestacoes
  TO 'ouvidoria_sistema'@'10.10.20.254';

FLUSH PRIVILEGES;
EOSQL
