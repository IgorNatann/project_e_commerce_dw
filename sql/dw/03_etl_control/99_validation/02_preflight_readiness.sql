-- ========================================
-- SCRIPT: 02_preflight_readiness.sql
-- OBJETIVO: checklist de prontidao antes do primeiro run ETL
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT 'PRE-FLIGHT ETL - PRONTIDAO';
PRINT '========================================';

SELECT
    CASE WHEN SCHEMA_ID('ctl') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS schema_ctl,
    CASE WHEN SCHEMA_ID('audit') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS schema_audit,
    CASE WHEN OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS table_ctl_etl_control,
    CASE WHEN OBJECT_ID('audit.etl_run', 'U') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS table_audit_etl_run,
    CASE WHEN OBJECT_ID('audit.etl_run_entity', 'U') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS table_audit_etl_run_entity;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL
BEGIN
    SELECT
        COUNT(*) AS total_entities,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_entities,
        SUM(CASE WHEN is_active = 1 AND source_table IS NOT NULL AND target_table IS NOT NULL THEN 1 ELSE 0 END) AS active_entities_mapped
    FROM ctl.etl_control;

    SELECT
        entity_name,
        source_table,
        target_table,
        watermark_updated_at,
        watermark_id,
        batch_size,
        cutoff_minutes,
        is_active
    FROM ctl.etl_control
    ORDER BY entity_name;
END
ELSE
BEGIN
    PRINT 'Tabela ctl.etl_control nao encontrada.';
END;
GO

IF OBJECT_ID('audit.etl_run', 'U') IS NOT NULL
BEGIN
    SELECT
        COUNT(*) AS total_runs,
        SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS runs_success,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS runs_failed,
        SUM(CASE WHEN status = 'partial' THEN 1 ELSE 0 END) AS runs_partial
    FROM audit.etl_run;
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_run nao encontrada.';
END;
GO

PRINT 'CRITERIO MINIMO PARA 1o RUN:';
PRINT '- schemas ctl e audit = OK';
PRINT '- tabelas ctl.etl_control, audit.etl_run e audit.etl_run_entity = OK';
PRINT '- active_entities > 0 em ctl.etl_control';
GO
