-- ========================================
-- SCRIPT: 01_checks.sql
-- OBJETIVO: validacao minima do controle ETL
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '1) Schemas esperados';
SELECT name AS schema_name
FROM sys.schemas
WHERE name IN ('ctl', 'audit')
ORDER BY name;
GO

PRINT '2) Tabelas de controle/auditoria';
SELECT
    OBJECT_SCHEMA_NAME(object_id) AS schema_name,
    name AS table_name
FROM sys.tables
WHERE OBJECT_SCHEMA_NAME(object_id) IN ('ctl', 'audit')
  AND name IN ('etl_control', 'etl_run', 'etl_run_entity')
ORDER BY schema_name, table_name;
GO

PRINT '3) Entidades cadastradas em ctl.etl_control';
SELECT
    entity_name,
    source_table,
    target_table,
    source_pk_column,
    watermark_updated_at,
    watermark_id,
    batch_size,
    cutoff_minutes,
    is_active
FROM ctl.etl_control
ORDER BY entity_name;
GO

PRINT '4) Ultimas execucoes (se houver)';
SELECT TOP (20)
    run_id,
    entities_requested,
    started_by,
    started_at,
    finished_at,
    status,
    entities_succeeded,
    entities_failed
FROM audit.etl_run
ORDER BY run_id DESC;
GO

PRINT '5) Ultimas entidades executadas (se houver)';
SELECT TOP (20)
    run_entity_id,
    run_id,
    entity_name,
    status,
    extracted_count,
    upserted_count,
    soft_deleted_count,
    watermark_from_updated_at,
    watermark_from_id,
    watermark_to_updated_at,
    watermark_to_id
FROM audit.etl_run_entity
ORDER BY run_entity_id DESC;
GO
