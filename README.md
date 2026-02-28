# Data Warehouse E-commerce

Projeto de laboratorio para simular uma esteira real de dados OLTP -> DW em SQL Server, com ETL incremental e monitoramento.

## Estado atual

- Infra Docker one-shot pronta (`SQL Server + init + Streamlit monitor + Streamlit vendas + backup`).
- Auditoria de conexoes ativa (tabela `audit.connection_login_events` + arquivo `.sqlaudit`).
- Escopo validado ponta a ponta focado em `dim_cliente`.
- OLTP (`ECOMMERCE_OLTP`) e DW (`DW_ECOMMERCE`) inicializados automaticamente pelo bootstrap.

## Quick start (Docker)

Pre-requisitos:

- Docker Desktop (ou Docker Engine + Compose v2)
- PowerShell

Subir stack completa:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

Acessos padrao:

- SQL Server: `localhost:1433`
- Streamlit monitor ETL: `http://localhost:8501`
- Streamlit dashboard vendas: `http://localhost:8502`

Descer stack:

```powershell
powershell -ExecutionPolicy Bypass -File docker/down_stack.ps1
```

## O que o bootstrap ja entrega

- Cria databases: `ECOMMERCE_OLTP` e `DW_ECOMMERCE`.
- Cria schema/tabelas OLTP core e executa seed base + incremental.
- Cria estrutura minima DW para `dim_cliente`.
- Cria controle ETL (`ctl.etl_control`) e tabelas de auditoria (`audit`).
- Ativa somente `dim_cliente` no controle ETL por padrao.
- Cria logins tecnicos `etl_monitor` e `etl_backup`.

## Fluxo de trabalho recomendado

1. Subir stack Docker com `docker/up_stack.ps1`.
2. Validar monitoramento no Streamlit.
3. Rodar ETL de `dim_cliente`.
4. Expandir para proximas dimensoes apos estabilizar observabilidade.

## Estrutura principal

```text
project_e-commerce_dw/
|-- docker/
|-- docs/
|-- python/
|   `-- etl/
|-- scripts/
`-- sql/
    |-- dw/
    `-- oltp/
```

## Documentacao

- [Infra Docker one-shot](docker/README.md)
- [Guia SQL (Docker-first)](sql/README.md)
- [ETL Python](python/etl/README.md)
- [OLTP (fonte)](sql/oltp/README.md)
- [Controle ETL e auditoria](sql/dw/03_etl_control/README.md)
- [Views auxiliares](sql/dw/04_views/README.md)
- [Contratos de dados](docs/contracts/README.md)
- [Queries analiticas](docs/queries/README.md)

## Observacao de escopo

As tabelas fato e parte das dimensoes continuam no repositorio, mas a validacao operacional atual da infra Docker esta priorizada em `dim_cliente`.
