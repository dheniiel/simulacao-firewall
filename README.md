# Simulação de Firewall — Ouvidoria Municipal

Ambiente Docker que segmenta a rede de uma prefeitura em **Internet**, **LAN** e **DMZ**, com um container **firewall (iptables)** como único caminho entre elas. Política padrão **DROP** e apenas liberações explícitas.

📄 Relatório técnico completo (case, diagnóstico, matriz de regras e testes): [`docs/RELATORIO.md`](docs/RELATORIO.md)

## Requisitos

- Windows 10/11 com **Docker Desktop** (backend WSL 2, containers Linux) e Git.
- Portas livres: `8080` no host.

## Como executar (PowerShell)

```powershell
git clone https://github.com/dheniiel/simulacao-firewall.git
cd simulacao-firewall
docker compose up -d --build
docker compose ps          # aguarde dmz-db ficar "healthy" (~30 s na 1ª vez)
```

Portal do cidadão no navegador: <http://localhost:8080/?protocolo=OUV-2026-0001>

Para encerrar: `docker compose down` (use `docker compose down -v` para apagar também o banco).

> As senhas do laboratório têm valor padrão. Para trocá-las, copie `.env.example` para `.env`, edite e rode `docker compose down -v; docker compose up -d --build`.

## Topologia

```
  Internet 203.0.113.0/24          LAN 10.10.10.0/24 (internal)
  net-cidadao  .50                 lan-estacao .10   lan-sistema .20
        │                                 │               │
        └──── .254 ┌──────────────┐ .254 ─┴───────────────┘
                   │   firewall   │  iptables · ip_forward=1 · NET_ADMIN
                   └──────────────┘
                          │ .254
             DMZ 10.10.20.0/24 (internal)
             dmz-web .10 (Apache/PHP)   dmz-db .20 (MySQL)
```

| Container | Rede | Papel |
|---|---|---|
| `firewall` | todas | Gateway: filtra (FORWARD/INPUT) e publica os serviços da DMZ via DNAT |
| `dmz-web` | DMZ | Portal público de consulta de protocolos (somente leitura) |
| `dmz-db` | DMZ | MySQL 8.4 com usuários de menor privilégio |
| `lan-sistema` | LAN | Sistema interno que cadastra/altera/exclui manifestações |
| `lan-estacao` | LAN | Estação de trabalho (Alpine + curl, nmap) |
| `net-cidadao` | Internet | Cidadão externo (Alpine + curl, nmap) |

## Estrutura

```
docker-compose.yml        redes, IPs fixos, capabilities, volume e healthcheck
firewall/firewall.sh      regras iptables (carregadas no ENTRYPOINT)
web/  sistema-interno/    aplicações PHP
db/                       imagem MySQL + scripts de criação (tabelas e usuários)
ferramentas/              imagem Alpine das estações de teste
docs/RELATORIO.md         relatório técnico
```

## Validação rápida

```powershell
docker compose exec lan-estacao curl -s -o /dev/null -w "%{http_code}\n" http://10.10.10.254/   # 200 (liberado)
docker compose exec lan-estacao nmap -Pn -p 3306 10.10.10.254                                  # filtered (bloqueado)
docker compose exec firewall iptables -L FORWARD -v -n --line-numbers                          # contadores das regras
```

O roteiro completo, com o porquê de cada resultado, está na seção 4 do [relatório](docs/RELATORIO.md#4-metodologia-de-testes-e-validação).
