# Simulação de Firewall — Ouvidoria Municipal

Laboratório em Docker que simula a rede de uma prefeitura segmentada em **Internet**, **LAN** e **DMZ**. Um container **firewall com iptables** é o único caminho entre as redes, com política padrão **DROP** e apenas liberações explícitas.

O cenário é a Ouvidoria Municipal: o cidadão consulta o andamento de uma manifestação pela Internet (portal na DMZ, somente leitura), enquanto os servidores da prefeitura cadastram e alteram manifestações por um sistema interno na LAN.

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Orquestração | Docker Compose (redes com IP fixo, healthcheck, volume) |
| Firewall | Alpine 3.20 + `iptables` (filter e NAT) |
| Aplicações | PHP 8.3 + Apache, PDO MySQL |
| Banco de dados | MySQL 8.4 |
| Estações de teste | Alpine 3.20 + `curl`, `nmap`, `iproute2` |

## Requisitos

- Docker Desktop (Windows 10/11 com WSL 2) ou Docker Engine + Compose v2 no Linux.
- Git.
- Porta `8080` livre no host.

## Como executar

```powershell
git clone https://github.com/dheniiel/simulacao-firewall.git
cd simulacao-firewall
docker compose up -d --build
docker compose ps        # aguarde dmz-db ficar "healthy" (~30 s na 1ª vez)
```

- **Portal do cidadão:** <http://localhost:8080/?protocolo=OUV-2026-0001>
- **Sistema interno:** não é publicado no host (fica só na LAN). Teste a partir da estação da LAN:
  `docker compose exec lan-estacao curl -s http://10.10.10.20/`
- **Regras carregadas:** `docker compose logs firewall`
- **Encerrar:** `docker compose down` (com `-v` apaga também o banco).

### Senhas

As senhas têm valores padrão de laboratório. Para trocá-las:

```powershell
Copy-Item .env.example .env     # edite os valores (apenas letras, números, - e _)
docker compose down -v; docker compose up -d --build
```

O `.env` está no `.gitignore`, então as senhas reais não vão para o repositório.

## Topologia

```
  Internet 203.0.113.0/24          LAN 10.10.10.0/24 (internal)
  net-cidadao  .50                 lan-estacao .10   lan-sistema .20
        │                                 │               │
        └──── .254 ┌──────────────┐ .254 ─┴───────────────┘
   localhost:8080 ─│   firewall   │  iptables · ip_forward=1 · NET_ADMIN
                   └──────────────┘
                          │ .254
             DMZ 10.10.20.0/24 (internal)
             dmz-web .10 (Apache/PHP)   dmz-db .20 (MySQL)
```

LAN e DMZ são redes `internal: true`: não têm saída pelo host, só pelo firewall.

| Container | Rede / IP | Papel |
|---|---|---|
| `firewall` | todas (`.254`) | Gateway: filtra o tráfego e publica os serviços da DMZ via DNAT |
| `dmz-web` | DMZ `10.10.20.10` | Portal público de consulta de protocolos (somente leitura) |
| `dmz-db` | DMZ `10.10.20.20` | MySQL com usuários de menor privilégio e dados persistentes |
| `lan-sistema` | LAN `10.10.10.20` | Sistema interno: cadastra, altera, exclui e lista manifestações |
| `lan-estacao` | LAN `10.10.10.10` | Estação de trabalho de um servidor (ferramentas de teste) |
| `net-cidadao` | Internet `203.0.113.50` | Cidadão externo (ferramentas de teste) |

## Estrutura do projeto

```
.
├── docker-compose.yml          # redes, IPs fixos, capabilities, volume e healthcheck
├── .env.example                # modelo para trocar as senhas padrão
├── .gitattributes              # força LF em .sh/.sql/.yml/.php/Dockerfile (clone no Windows)
├── firewall/
│   ├── Dockerfile              # Alpine + iptables; executa firewall.sh no ENTRYPOINT
│   └── firewall.sh             # política DROP, NAT e regras R1–R6
├── web/                        # portal do cidadão (DMZ)
│   ├── Dockerfile
│   └── src/index.php           # consulta por protocolo, só SELECT
├── sistema-interno/            # sistema da LAN
│   ├── Dockerfile
│   └── src/index.php           # CRUD das manifestações
├── db/
│   ├── Dockerfile              # MySQL 8.4 + scripts de inicialização
│   └── init/
│       ├── 01-estrutura.sql    # tabela manifestacoes + 5 registros fictícios
│       └── 02-usuarios.sh      # usuários de leitura e de sistema
└── ferramentas/
    └── Dockerfile              # Alpine com curl, nmap e iproute2
```

## Regras do firewall

O `firewall.sh` descobre as interfaces pelo IP (o Docker não garante a ordem `eth0/eth1/eth2`), limpa as regras anteriores e aplica:

**Política padrão:** `INPUT DROP`, `FORWARD DROP`, `OUTPUT ACCEPT`. Conexões `ESTABLISHED,RELATED` são aceitas e pacotes `INVALID` são descartados.

**NAT (publicação de serviços):** os clientes nunca acessam o IP da DMZ diretamente; falam com o IP do firewall na própria rede.

| Origem | Destino publicado | Encaminha para |
|---|---|---|
| Internet | `203.0.113.254:80` | `dmz-web:80` |
| LAN | `10.10.10.254:80` | `dmz-web:80` |
| LAN | `10.10.10.254:3306` | `dmz-db:3306` |

Na saída para a DMZ é aplicado `MASQUERADE`, para que as respostas voltem pelo firewall. Por isso a DMZ vê todas as conexões vindo de `10.10.20.254`.

**Matriz de regras:**

| Regra | Cadeia | Tráfego | Ação |
|---|---|---|---|
| R1 | FORWARD | Internet → `dmz-web` TCP 80 | ACCEPT |
| R2 | FORWARD | LAN → `dmz-web` TCP 80 | ACCEPT |
| R3 | FORWARD | Somente `lan-sistema` (`10.10.10.20`) → `dmz-db` TCP 3306 | ACCEPT |
| R4 | FORWARD | Demais hosts da LAN → `dmz-db` TCP 3306 (vem depois da R3) | DROP |
| R5 | FORWARD | DMZ → LAN, conexões novas (contenção se a DMZ for invadida) | DROP |
| R6 | INPUT | Ping da LAN para o gateway `10.10.10.254` | ACCEPT |
| — | todas | Qualquer outro tráfego | DROP (política padrão) |

## Banco de dados

Banco `ouvidoria`, tabela `manifestacoes` (protocolo, tipo, assunto, secretaria, status, data de abertura, prazo de resposta e último andamento), com cinco registros fictícios de `OUV-2026-0001` a `OUV-2026-0005`, sem dados pessoais. Os scripts de `db/init/` rodam apenas na primeira subida, com o volume vazio.

| Usuário | Host permitido | Permissões | Usado por |
|---|---|---|---|
| `root` | `localhost` | todas | administração local (sem acesso pela rede) |
| `ouvidoria_leitura` | `10.10.20.10` | `SELECT` | portal do cidadão |
| `ouvidoria_sistema` | `10.10.20.254` | `SELECT, INSERT, UPDATE, DELETE` | sistema interno |

O usuário do sistema é amarrado a `10.10.20.254` por causa do MASQUERADE; quem garante que apenas o `10.10.10.20` chega ao banco é a regra **R3**.

## Aplicações

- **Portal do cidadão (`web/`):** formulário de consulta por protocolo. Usa consulta parametrizada (contra SQL Injection), escapa a saída com `htmlspecialchars` (contra XSS) e mostra ao usuário só mensagens genéricas de erro, registrando o detalhe no log do servidor.
- **Sistema interno (`sistema-interno/`):** lista, cadastra, atualiza (status, prazo e andamento) e exclui manifestações. O protocolo `OUV-AAAA-NNNN` é gerado a partir do `id`, então um protocolo excluído nunca é reaproveitado.

## Validação

| Teste | Comando | Esperado |
|---|---|---|
| Cidadão acessa o portal (R1) | `docker compose exec net-cidadao curl -s -o /dev/null -w "%{http_code}\n" http://203.0.113.254/` | `200` |
| Cidadão tenta o MySQL | `docker compose exec net-cidadao nmap -Pn -p 3306 203.0.113.254` | `filtered` |
| LAN acessa o portal (R2) | `docker compose exec lan-estacao curl -s -o /dev/null -w "%{http_code}\n" http://10.10.10.254/` | `200` |
| Estação tenta o MySQL (R4) | `docker compose exec lan-estacao nmap -Pn -p 3306 10.10.10.254` | `filtered` |
| Sistema interno lê o banco (R3) | `docker compose exec lan-estacao curl -s http://10.10.10.20/ \| grep OUV-` | lista de protocolos |
| Ping da LAN ao gateway (R6) | `docker compose exec lan-estacao ping -c 2 10.10.10.254` | respostas |
| Ping da Internet ao firewall | `docker compose exec net-cidadao ping -c 2 -W 2 203.0.113.254` | sem resposta |
| Contadores das regras | `docker compose exec firewall iptables -L FORWARD -v -n --line-numbers` | pacotes nas regras testadas |

## Solução de problemas

- **Portal mostra "Serviço temporariamente indisponível":** o banco ainda está subindo; aguarde `dmz-db` ficar `healthy`.
- **Senha trocada no `.env` não funcionou:** os usuários só são criados com o volume vazio; rode `docker compose down -v` antes de subir de novo.
- **Firewall reinicia com "interfaces não encontradas":** confira se os IPs do `docker-compose.yml` e do `firewall.sh` são os mesmos.
- **Erro de `\r` em scripts no Windows:** o `.gitattributes` e os Dockerfiles já convertem para LF; se editou os arquivos, salve com fim de linha LF.
