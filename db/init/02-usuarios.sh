#!/bin/bash
# Usuarios do banco com o MENOR PRIVILEGIO necessario:
#  - Portal do cidadao (DMZ 10.10.20.10): somente leitura.
#  - Sistema interno (LAN 10.10.10.20): leitura e escrita. Por causa do
#    MASQUERADE do firewall, o MySQL ve essa conexao vindo de 10.10.20.254;
#    quem garante que so o 10.10.10.20 chega aqui e a regra R3 do firewall.
mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE USER 'ouvidoria_leitura'@'10.10.20.10' IDENTIFIED BY '${DB_READ_PASSWORD}';
GRANT SELECT ON ouvidoria.manifestacoes TO 'ouvidoria_leitura'@'10.10.20.10';

CREATE USER 'ouvidoria_sistema'@'10.10.20.254' IDENTIFIED BY '${DB_SISTEMA_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ouvidoria.manifestacoes
  TO 'ouvidoria_sistema'@'10.10.20.254';

FLUSH PRIVILEGES;
EOSQL
