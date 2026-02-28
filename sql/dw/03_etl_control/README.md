# DW - Controle ETL e auditoria

Esta pasta contem os scripts de controle operacional da carga incremental.

## Componentes

- `ctl.etl_control`: liga/desliga entidades e guarda watermark.
- `audit.etl_run` e `audit.etl_run_entity`: trilha de execucao do ETL.
- Auditoria de conexao em tabela (`audit.connection_login_events`).
- Auditoria nativa SQL Server em arquivo (`.sqlaudit`).

## Ordem de execucao

1. `01_create_schema_ctl.sql`
2. `02_create_etl_control.sql`
3. `03_create_audit_etl_tables.sql`
4. `04_seed_etl_control.sql`
5. `05_create_connection_audit.sql`
6. `06_configure_server_audit_file.sql`
7. `07_activate_dim_cliente_scope.sql`
8. `08_ensure_dim_cliente_contract.sql`
9. `09_ensure_dim_produto_contract.sql`
10. `10_ensure_fact_vendas_contract.sql`
11. `11_activate_fact_vendas_scope.sql`
12. `99_validation/01_checks.sql`
13. `99_validation/02_preflight_readiness.sql`
14. `99_validation/03_connection_audit_checks.sql`
15. `99_validation/04_server_audit_file_checks.sql`

## Com Docker

Esses scripts ja sao aplicados automaticamente pelo servico `sql-init`.

Subida one-shot:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

## Validacao rapida

```sql
USE DW_ECOMMERCE;
GO

SELECT entity_name, is_active, source_table, target_table
FROM ctl.etl_control
ORDER BY entity_name;

SELECT TOP 20 event_time_utc, login_name, host_name, program_name
FROM audit.connection_login_events
ORDER BY event_time_utc DESC;
```

## Escopo atual

`dim_cliente`, `dim_produto` e `fact_vendas` podem ser mantidas ativas conforme estrategia de rollout. O controle de escopo fica em `ctl.etl_control`.
