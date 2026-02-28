# Data Warehouse E-commerce

Projeto de laboratorio para simular um cenario real de dados `OLTP -> DW` em SQL Server, com ETL incremental, auditoria tecnica e monitoramento operacional via Streamlit.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022+-CC2927?style=flat&logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![Model](https://img.shields.io/badge/Model-Star%20Schema-blue)](https://en.wikipedia.org/wiki/Star_schema)
[![Method](https://img.shields.io/badge/Method-Kimball-green)](https://www.kimballgroup.com/)
[![Infra](https://img.shields.io/badge/Infra-Docker%20One--Shot-2496ED?style=flat&logo=docker)](docker/README.md)

## Sobre o projeto

Este repositorio combina modelagem dimensional com operacao de dados:

- OLTP de origem (`ECOMMERCE_OLTP`) com seeds e simulacao incremental.
- DW de destino (`DW_ECOMMERCE`) com dimensoes, fatos e views analiticas.
- ETL incremental em Python com watermark e auditoria de execucao.
- Monitoramento Streamlit com visao de pipeline, qualidade, SLA e auditoria tecnica.
- Objetivo final: auditar operacionalmente todas as dimensoes e fatos do projeto.

## Objetivo final (escopo completo)

- Garantir execucao auditada para todo o modelo dimensional:
7 dimensoes (`dim_*`) e 3 fatos (`fact_*`).
- Rastrear cada etapa de carga em `audit.etl_run` e `audit.etl_run_entity`.
- Validar qualidade e reconciliacao por entidade/fato antes da evolucao de escopo.
- Monitorar SLA, atrasos, falhas recorrentes e saude de conectividade em painel unico.

## Escopo atual validado

- Infra Docker one-shot: `SQL Server + sql-init + Streamlit + backup`.
- Auditoria de conexao ativa: `audit.connection_login_events` e SQL Server Audit (`.sqlaudit`).
- Entidades ativas por padrao no controle ETL: `dim_cliente` e `dim_produto`.
- Fluxo validado ponta a ponta: extracao OLTP, upsert DW, watermark, trilha em `audit.*` e monitoramento visual.

## Status de evolucao

1. Fase validada: `dim_cliente` e `dim_produto`.
2. Em andamento: onboarding progressivo das demais `dim_*` e `fact_*`.
3. Meta: operacao completa com monitoramento e auditoria para todo o DW.

## Arquitetura resumida

1. Fonte OLTP (`sql/oltp`): tabelas transacionais + seed base + seed incremental.
2. Destino DW (`sql/dw`): dimensoes, fatos, views e contratos de estrutura.
3. Controle ETL (`ctl` e `audit`): estado incremental, runs e entidades por run.
4. ETL Python (`python/etl`): runner, entidades, SQL de extract/upsert e dashboard.
5. Operacao Docker (`docker`): stack one-shot, variaveis, backup e health checks.

## Quick start (recomendado)

Pre-requisitos:

- Docker Desktop (ou Docker Engine + Compose v2)
- PowerShell

Subir a stack completa:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

Endpoints:

- SQL Server: `localhost:1433`
- Streamlit: `http://localhost:8501`

Descer a stack:

```powershell
powershell -ExecutionPolicy Bypass -File docker/down_stack.ps1
```

## Execucao ETL (container)

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_produto
docker exec dw_etl_monitor python python/etl/run_etl.py --entity all
```

## Estrutura real do repositorio

```text
project_e-commerce_dw/
|-- docker/
|-- docs/
|-- python/
|   |-- data_generation/
|   `-- etl/
|-- scripts/
|-- sql/
|   |-- dw/
|   `-- oltp/
`-- data/
```

## Documentacao principal

- [Infra Docker one-shot](docker/README.md)
- [Guia SQL (Docker-first)](sql/README.md)
- [ETL Python](python/etl/README.md)
- [Controle ETL e auditoria](sql/dw/03_etl_control/README.md)
- [Monitoramento Streamlit](python/etl/docs/05_monitoramento_streamlit.md)
- [OLTP (fonte)](sql/oltp/README.md)
- [Views auxiliares DW](sql/dw/04_views/README.md)
- [Contratos de dados](docs/contracts/README.md)
- [Queries analiticas](docs/queries/README.md)

## Apontamentos das atualizacoes recentes

- Infra Docker consolidada para operacao one-shot.
- Escopo operacional padrao evoluido de `dim_cliente` para `dim_cliente + dim_produto`.
- Streamlit evoluido para matriz geral de pipelines, timeline de execucao, qualidade/reconciliacao e painel de SLA/alertas.
- Auditoria tecnica consolidada no dashboard: conexoes, taxonomia de erros e correlacao temporal com falhas ETL.
- Direcionamento oficial de projeto atualizado para auditoria de todas as dimensoes e fatos.
