# Scripts SQL - OLTP (Fonte do ETL)

Este diretorio contem os scripts da base operacional `ECOMMERCE_OLTP`.
O objetivo e simular uma origem real para cargas incrementais no `DW_ECOMMERCE`.

## Ordem de Execucao

1. `00_setup/01_create_database.sql`
2. `00_setup/02_create_schemas.sql`
3. `01_ddl/01_create_tables_core.sql`
4. `99_validation/01_schema_checks.sql`

## Escopo da Fase 1

- modelagem fisica OLTP para entidades core
- padrao tecnico com `created_at`, `updated_at`, `deleted_at`
- indices para extracao incremental por `(updated_at, id)`

## Observacoes

- nesta fase nao ha carga massiva de dados
- sementes de dados (3 anos) entram na proxima fase
