# SQL OLTP (fonte do ETL)

Scripts da base operacional `ECOMMERCE_OLTP`, usada como origem para cargas incrementais no DW.

## Uso com Docker (recomendado)

Ao subir `docker/up_stack.ps1`, o servico `sql-init` executa automaticamente:

1. `00_setup/02_create_schemas.sql`
2. `01_ddl/01_create_tables_core.sql`
3. `02_seed/01_seed_base.sql`
4. `02_seed/02_seed_incremental.sql`

## Ordem manual completa

1. `00_setup/01_create_database.sql`
2. `00_setup/02_create_schemas.sql`
3. `01_ddl/01_create_tables_core.sql`
4. `99_validation/01_schema_checks.sql`
5. `02_seed/01_seed_base.sql`
6. `02_seed/02_seed_incremental.sql`
7. `99_validation/01_checks.sql`

## Objetivo

- Simular fonte OLTP real para ETL incremental.
- Fornecer dados com historico e alteracoes recentes.
- Permitir validacao de watermark por `updated_at + id`.

## Nota

O fluxo atual esta calibrado para validar `dim_cliente` primeiro.
