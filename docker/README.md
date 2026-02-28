# Stack Docker (one-shot)

Este diretorio sobe toda a infra de laboratorio em um comando:

- SQL Server 2022
- bootstrap automatico de OLTP + DW (rollout atual: 6 dimensoes + `fact_vendas` + `fact_metas` + `fact_descontos`)
- Streamlit para monitoramento ETL
- Streamlit para dashboard de vendas (R1)
- auditoria de conexoes (tabela + SQL Server Audit em arquivo)
- backup automatico para volume dedicado

## Subir stack

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

## Descer stack

```powershell
powershell -ExecutionPolicy Bypass -File docker/down_stack.ps1
```

## Verificar status

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
```

Servicos esperados:

- `dw_sqlserver`
- `dw_sql_init` (completa e finaliza)
- `dw_etl_monitor`
- `dw_dash_vendas`
- `dw_sql_backup`

## Endpoints

- SQL Server: `localhost:1433`
- Streamlit monitor ETL: `http://localhost:8501`
- Streamlit dashboard vendas: `http://localhost:8502`

## Arquivo de credenciais

- `docker/.env.sqlserver` (gerado no primeiro `up_stack.ps1`)
- base: `docker/.env.sqlserver.example`

Principais variaveis:

- `MSSQL_SA_PASSWORD`
- `MSSQL_MONITOR_PASSWORD` (usuario `etl_monitor` usado no Streamlit e no ETL das entidades monitoradas)
- `MSSQL_BACKUP_PASSWORD`
- `MSSQL_BI_PASSWORD` (usuario `bi_reader` usado pelo dashboard de vendas)
- `CONNECTION_AUDIT_RETENTION_DAYS`
- `BACKUP_INTERVAL_HOURS`
- `BACKUP_RETENTION_DAYS`
- `SQLSERVER_BIND_IP`, `SQLSERVER_PORT`
- `STREAMLIT_BIND_IP`, `STREAMLIT_PORT`
- `STREAMLIT_VENDAS_BIND_IP`, `STREAMLIT_VENDAS_PORT`

## Volumes persistentes

- `sqlserver_system` -> `/var/opt/mssql/.system`
- `sqlserver_data` -> `/var/opt/mssql/data`
- `sqlserver_log` -> `/var/opt/mssql/log`
- `sqlserver_secrets` -> `/var/opt/mssql/secrets`
- `sqlserver_backup` -> `/var/opt/mssql/backup`
- `sqlserver_audit` -> `/var/opt/mssql/audit`

## Limpeza de volumes legados

Dry-run:

```powershell
powershell -ExecutionPolicy Bypass -File docker/prune_legacy_sql_volumes.ps1
```

Aplicar:

```powershell
powershell -ExecutionPolicy Bypass -File docker/prune_legacy_sql_volumes.ps1 -Apply
```

## Escopo atual de validacao

A automacao da stack garante readiness operacional das entidades ETL implementadas:
`dim_cliente`, `dim_produto`, `dim_regiao`, `dim_equipe`, `dim_vendedor`, `dim_desconto`, `fact_vendas`, `fact_metas` e `fact_descontos`.

Observacao:
- o `sql-init` executa validacao automatica de rollout (`05_current_rollout_scope_checks.sql`);
- se o escopo ativo no `ctl.etl_control` ou as tabelas obrigatorias divergirem, o bootstrap falha para evitar stack inconsistente.

Observacao de persistencia:

- o bootstrap OLTP completo (DDL + seeds) roda apenas quando `core.customers` ainda nao existe;
- em reinicios normais, os dados OLTP persistidos em volume sao preservados.

Observacao de auditoria:

- a limpeza de `audit.connection_login_events` roda no `sql-init` e tambem no ciclo do `sql-backup` (retencao por `CONNECTION_AUDIT_RETENTION_DAYS`).

## Execucao rapida do ETL no container

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_produto
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_regiao
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_equipe
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_vendedor
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_desconto
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_vendas
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_metas
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_descontos
docker exec dw_etl_monitor python python/etl/run_etl.py --entity all
```
