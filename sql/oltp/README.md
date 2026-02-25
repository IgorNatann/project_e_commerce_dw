# Scripts SQL - OLTP (Fonte do ETL)

Este diretorio contem os scripts da base operacional `ECOMMERCE_OLTP`.
O objetivo e simular uma origem real para cargas incrementais no `DW_ECOMMERCE`.

## Ordem de Execucao

1. `00_setup/01_create_database.sql`
2. `00_setup/02_create_schemas.sql`
3. `01_ddl/01_create_tables_core.sql`
4. `99_validation/01_schema_checks.sql`
5. `02_seed/01_seed_base.sql`
6. `02_seed/02_seed_incremental.sql`
7. `99_validation/01_checks.sql`

## Escopo da Fase 1

- modelagem fisica OLTP para entidades core
- padrao tecnico com `created_at`, `updated_at`, `deleted_at`
- indices para extracao incremental por `(updated_at, id)`

## Escopo da Fase 2

- carga base set-based com 3 anos de historico
- simulacao incremental com inserts, updates e soft delete
- checks de qualidade para integridade e readiness de watermark

## Observacoes

- o seed base foi calibrado para volume medio de laboratorio
- os scripts evitam cursor/while e priorizam operacoes set-based
