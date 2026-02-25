# OLTP SQL Scripts

This folder contains the source (OLTP) scripts used to simulate a real extract process to DW_ECOMMERCE.

## Execution Order

1. `00_setup/01_create_database.sql`
2. `00_setup/02_create_schemas.sql`
3. `01_ddl/01_create_tables_core.sql`
4. `02_seed/01_seed_base.sql`
5. `02_seed/02_seed_incremental.sql`
6. `99_validation/01_checks.sql`

## Scope

- Source database: `ECOMMERCE_OLTP`
- Purpose: feed incremental ETL into `DW_ECOMMERCE`
- Pattern: staging extract with watermark (`updated_at`, `id`)

## Notes

- Keep OLTP schema operational and normalized enough for realistic extraction.
- Do not add DW-style denormalized dimensions/facts in this layer.