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
7. `08_ensure_dim_cliente_contract.sql`
8. `09_ensure_dim_produto_contract.sql`
9. `13_ensure_fact_vendas_table.sql`
10. `10_ensure_fact_vendas_contract.sql`
11. `14_ensure_fact_metas_table.sql`
12. `15_ensure_fact_descontos_table.sql`
13. `12_activate_current_rollout_scope.sql`
14. `99_validation/05_current_rollout_scope_checks.sql`
15. `99_validation/01_checks.sql`
16. `99_validation/02_preflight_readiness.sql`
17. `99_validation/03_connection_audit_checks.sql`
18. `99_validation/04_server_audit_file_checks.sql`

Scripts legados de rollout:

- `07_activate_dim_cliente_scope.sql` (rollout inicial limitado)
- `11_activate_fact_vendas_scope.sql` (ativacao pontual da fact)

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

O rollout padrao ativa as entidades ETL implementadas em Python:
`dim_cliente`, `dim_produto`, `dim_regiao`, `dim_equipe`, `dim_vendedor`, `dim_desconto`, `fact_vendas`, `fact_metas` e `fact_descontos`.
