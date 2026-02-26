-- ========================================
-- SCRIPT: 99_validation/01_checks.sql
-- OBJETIVO: validar estrutura de controle e auditoria do ETL
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

DECLARE @results TABLE
(
    check_order INT NOT NULL,
    check_name VARCHAR(120) NOT NULL,
    status VARCHAR(10) NOT NULL,
    details VARCHAR(400) NOT NULL
);

INSERT INTO @results (check_order, check_name, status, details)
SELECT
    10,
    'schema_ctl_existe',
    CASE WHEN EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl') THEN 'PASS' ELSE 'FAIL' END,
    'schema ctl'
UNION ALL
SELECT
    10,
    'schema_audit_existe',
    CASE WHEN EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit') THEN 'PASS' ELSE 'FAIL' END,
    'schema audit';

INSERT INTO @results (check_order, check_name, status, details)
SELECT
    20,
    'tabela_ctl_etl_control',
    CASE WHEN OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    'controle de watermark'
UNION ALL
SELECT
    20,
    'tabela_audit_etl_run',
    CASE WHEN OBJECT_ID('audit.etl_run', 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    'auditoria por execucao'
UNION ALL
SELECT
    20,
    'tabela_audit_etl_run_entity',
    CASE WHEN OBJECT_ID('audit.etl_run_entity', 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    'auditoria por entidade'
UNION ALL
SELECT
    20,
    'tabela_audit_etl_rejects',
    CASE WHEN OBJECT_ID('audit.etl_rejects', 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    'linhas rejeitadas';

IF OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL
BEGIN
    INSERT INTO @results (check_order, check_name, status, details)
    SELECT
        30,
        'watermark_nulo',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        CONCAT('linhas_com_nulo=', COUNT(*))
    FROM ctl.etl_control
    WHERE watermark_updated_at IS NULL
       OR watermark_id IS NULL;

    INSERT INTO @results (check_order, check_name, status, details)
    SELECT
        40,
        'entidades_ativas_minimo',
        CASE
            WHEN COUNT(*) >= 1 THEN 'PASS'
            ELSE 'WARN'
        END,
        CONCAT('ativas=', COUNT(*))
    FROM ctl.etl_control
    WHERE is_active = 1;
END;

SELECT
    check_order,
    check_name,
    status,
    details
FROM @results
ORDER BY check_order, check_name;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS total_pass,
    SUM(CASE WHEN status = 'WARN' THEN 1 ELSE 0 END) AS total_warn,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS total_fail
FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
BEGIN
    THROW 50002, 'Validacao da camada de controle ETL encontrou falhas bloqueantes.', 1;
END;
GO

