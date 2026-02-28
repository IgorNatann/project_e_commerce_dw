# Data Warehouse E-commerce

Projeto de laboratorio para simular um cenario real de dados `OLTP -> DW` em SQL Server, com ETL incremental, auditoria tecnica e monitoramento operacional via Streamlit.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022+-CC2927?style=flat&logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![Model](https://img.shields.io/badge/Model-Star%20Schema-blue)](https://en.wikipedia.org/wiki/Star_schema)
[![Method](https://img.shields.io/badge/Method-Kimball-green)](https://www.kimballgroup.com/)
[![Infra](https://img.shields.io/badge/Infra-Docker%20One--Shot-2496ED?style=flat&logo=docker)](docker/README.md)

- Infra Docker one-shot pronta (`SQL Server + init + Streamlit monitor + Streamlit vendas + backup`).
- Auditoria de conexoes ativa (tabela `audit.connection_login_events` + arquivo `.sqlaudit`).
- Escopo validado ponta a ponta para `dim_cliente`, `dim_produto`, `dim_regiao`, `dim_equipe`, `dim_vendedor`, `dim_desconto`, `fact_vendas` e `fact_metas`.
- OLTP (`ECOMMERCE_OLTP`) e DW (`DW_ECOMMERCE`) inicializados automaticamente pelo bootstrap.

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
- Readiness operacional no bootstrap da stack para as entidades ETL implementadas (`dim_cliente`, `dim_produto`, `dim_regiao`, `dim_equipe`, `dim_vendedor`, `dim_desconto`, `fact_vendas` e `fact_metas`).
- ETL incremental Python implementado para `dim_cliente`, `dim_produto`, `dim_regiao`, `dim_vendedor`, `dim_equipe`, `dim_desconto`, `fact_vendas` e `fact_metas`.
- Dashboards publicados: monitoramento ETL (`:8501`) e vendas R1 (`:8502`).
- Fluxo validado ponta a ponta: extracao OLTP, upsert DW, watermark, trilha em `audit.*` e monitoramento visual.

## Status de evolucao

1. Base operacional concluida: OLTP funcional, DW base, ETL incremental inicial e monitoramento tecnico.
2. Em andamento: ampliacao da cobertura operacional para `fact_descontos`.
3. Em andamento: publicacao dos dashboards de metas/atingimento e descontos/ROI.
4. Meta: suite automatizada de testes, alertas de falha/SLA e runbook operacional formal.

## Arquitetura resumida

1. Fonte OLTP (`sql/oltp`): tabelas transacionais + seed base + seed incremental.
2. Destino DW (`sql/dw`): dimensoes, fatos, views e contratos de estrutura.
3. Controle ETL (`ctl` e `audit`): estado incremental, runs e entidades por run.
4. ETL Python (`python/etl`): runner, entidades e SQL de extract/upsert.
5. Dashboards (`dashboards/streamlit`): monitoramento operacional e dashboards de negocio.
6. Operacao Docker (`docker`): stack one-shot, variaveis, backup e health checks.

Arquitetura visual (Mermaid):

- [Arquitetura atual do projeto](docs/diagrams/02_arquitetura_atual.md)

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
- Streamlit monitor ETL: `http://localhost:8501`
- Streamlit dashboard vendas: `http://localhost:8502`

Descer a stack:

```powershell
powershell -ExecutionPolicy Bypass -File docker/down_stack.ps1
```

## Execucao ETL (container)

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_produto
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_regiao
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_vendedor
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_equipe
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_desconto
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_vendas
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_metas
docker exec dw_etl_monitor python python/etl/run_etl.py --entity all
```

## Estrutura real do repositorio

```text
project_e-commerce_dw/
|-- dashboards/
|   `-- streamlit/
|-- docker/
|-- docs/
|-- notebooks/
|-- python/
|   |-- data_generation/
|   |-- etl/
|   |-- tests/
|   `-- utils/
|-- scripts/
|-- sql/
|   |-- dw/
|   `-- oltp/
|-- tests/
`-- data/
```

## Documentacao principal

- [Infra Docker one-shot](docker/README.md)
- [Arquitetura atual (runtime + tecnologias)](docs/diagrams/02_arquitetura_atual.md)
- [Indice de diagramas](docs/diagrams/README.md)
- [Guia SQL (Docker-first)](sql/README.md)
- [ETL Python](python/etl/README.md)
- [Guia de Dashboards](dashboards/README.md)
- [Controle ETL e auditoria](sql/dw/03_etl_control/README.md)
- [Monitoramento Streamlit](dashboards/streamlit/monitoring/README.md)
- [Dashboard de vendas R1](dashboards/streamlit/vendas/README.md)
- [OLTP (fonte)](sql/oltp/README.md)
- [Views auxiliares DW](sql/dw/04_views/README.md)
- [Seguranca de consumo BI](sql/dw/05_security/README.md)
- [Contratos de dados](docs/contracts/README.md)
- [Queries analiticas](docs/queries/README.md)

## Apontamentos das atualizacoes recentes

- Infra Docker consolidada para operacao one-shot.
- Escopo operacional de bootstrap consolidado para as entidades ETL implementadas (6 dimensoes + `fact_vendas` + `fact_metas`).
- ETL incremental implementado para as entidades do rollout atual com onboarding via `ctl.etl_control`.
- Streamlit evoluido para matriz geral de pipelines, timeline de execucao, qualidade/reconciliacao e painel de SLA/alertas.
- Auditoria tecnica consolidada no dashboard: conexoes, taxonomia de erros e correlacao temporal com falhas ETL.
- Direcionamento oficial de projeto atualizado para auditoria de todas as dimensoes e fatos.
