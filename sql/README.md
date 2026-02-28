# SQL - Guia de execucao (Docker-first)

Este diretorio contem os scripts SQL do projeto em duas camadas:

- `sql/oltp`: base transacional de origem (`ECOMMERCE_OLTP`)
- `sql/dw`: base analitica de destino (`DW_ECOMMERCE`)

## Caminho recomendado

Use a stack Docker one-shot para evitar setup manual:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

O servico `sql-init` ja executa o bootstrap do rollout atual:
`dim_data`, `dim_cliente`, `dim_produto`, `dim_regiao`, `dim_equipe`, `dim_vendedor`, `dim_desconto` e `fact_vendas`.
Tambem configura o perfil de leitura `bi_reader` para consumo do dashboard de vendas.

Observacao:
- `sql/dw/02_ddl/dimensions/02_dim_cliente.sql` esta em modo idempotente (nao faz `DROP TABLE` e preserva dados).
- o escopo ativo no controle ETL e definido por `sql/dw/03_etl_control/12_activate_current_rollout_scope.sql`.

## Ordem manual (quando necessario)

### 1) OLTP

1. `sql/oltp/00_setup/01_create_database.sql`
2. `sql/oltp/00_setup/02_create_schemas.sql`
3. `sql/oltp/01_ddl/01_create_tables_core.sql`
4. `sql/oltp/02_seed/01_seed_base.sql`
5. `sql/oltp/02_seed/02_seed_incremental.sql`
6. `sql/oltp/99_validation/01_schema_checks.sql`
7. `sql/oltp/99_validation/01_checks.sql`

### 2) DW base

1. `sql/dw/01_setup/01_create_database.sql`
2. `sql/dw/01_setup/02_create_schemas.sql`
3. `sql/dw/01_setup/03_configure_database.sql`
4. `sql/dw/02_ddl/dimensions/01_dim_data.sql`
5. `sql/dw/02_ddl/dimensions/02_dim_cliente.sql`
6. `sql/dw/02_ddl/dimensions/03_dim_produto.sql`
7. `sql/dw/02_ddl/dimensions/04_dim_regiao.sql`
8. `sql/dw/02_ddl/dimensions/05_dim_equipe.sql`
9. `sql/dw/02_ddl/dimensions/06_dim_vendedor.sql`
10. `sql/dw/02_ddl/dimensions/07_dim_desconto.sql`
11. `sql/dw/02_ddl/facts/01_fact_vendas.sql`

### 3) Controle ETL e auditoria

1. `sql/dw/03_etl_control/01_create_schema_ctl.sql`
2. `sql/dw/03_etl_control/02_create_etl_control.sql`
3. `sql/dw/03_etl_control/03_create_audit_etl_tables.sql`
4. `sql/dw/03_etl_control/04_seed_etl_control.sql`
5. `sql/dw/03_etl_control/05_create_connection_audit.sql`
6. `sql/dw/03_etl_control/06_configure_server_audit_file.sql`
7. `sql/dw/03_etl_control/08_ensure_dim_cliente_contract.sql`
8. `sql/dw/03_etl_control/09_ensure_dim_produto_contract.sql`
9. `sql/dw/03_etl_control/13_ensure_fact_vendas_table.sql`
10. `sql/dw/03_etl_control/10_ensure_fact_vendas_contract.sql`
11. `sql/dw/03_etl_control/12_activate_current_rollout_scope.sql`
12. `sql/dw/05_security/01_create_bi_reader.sql`
13. `sql/dw/03_etl_control/99_validation/01_checks.sql`
14. `sql/dw/03_etl_control/99_validation/02_preflight_readiness.sql`
15. `sql/dw/03_etl_control/99_validation/03_connection_audit_checks.sql`
16. `sql/dw/03_etl_control/99_validation/04_server_audit_file_checks.sql`

## Validacao rapida

```sql
USE DW_ECOMMERCE;
GO

SELECT entity_name, is_active
FROM ctl.etl_control
ORDER BY entity_name;

SELECT TOP 20 event_time_utc, login_name, host_name, program_name
FROM audit.connection_login_events
ORDER BY event_time_utc DESC;
```

## Observacao de escopo

A stack Docker aplica o rollout do ETL ja implementado (6 dimensoes + `fact_vendas`). A expansao para `fact_metas` e `fact_descontos` continua nas proximas etapas.
