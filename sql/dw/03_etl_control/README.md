# Fase 3 - Controle ETL (SQL)

Esta pasta cria a base operacional para execucao incremental:

- controle de watermark por entidade (`ctl.etl_control`);
- auditoria de execucao (`audit.etl_run` e `audit.etl_run_entity`);
- seed das entidades iniciais.

## Ordem de execucao

1. `01_create_schema_ctl.sql`
2. `02_create_etl_control.sql`
3. `03_create_audit_etl_tables.sql`
4. `04_seed_etl_control.sql`
5. `99_validation/01_checks.sql` (validacao)

## Resultado esperado

Depois da execucao:

- schema `ctl` criado;
- tabela `ctl.etl_control` populada;
- tabelas de auditoria criadas no schema `audit`;
- validacoes retornando objetos e entidades cadastradas.
