-- ========================================
-- SCRIPT: 02_create_schemas.sql
-- DESCRICAO: criacao dos schemas organizacionais
-- AUTOR: Igor
-- DATA: 2025-12-01
-- PRE-REQUISITO: 01_create_database.sql
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIACAO DOS SCHEMAS';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. SCHEMA: dim (Dimensoes)
-- ========================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
BEGIN
    EXEC('CREATE SCHEMA dim AUTHORIZATION dbo');
    PRINT 'Schema [dim] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [dim] ja existe.';
END
GO

-- ========================================
-- 2. SCHEMA: fact (Fatos)
-- ========================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
BEGIN
    EXEC('CREATE SCHEMA fact AUTHORIZATION dbo');
    PRINT 'Schema [fact] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [fact] ja existe.';
END
GO

-- ========================================
-- 3. SCHEMA: stg (Staging)
-- ========================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo');
    PRINT 'Schema [stg] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [stg] ja existe.';
END
GO

-- ========================================
-- 4. SCHEMA: audit (Auditoria)
-- ========================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo');
    PRINT 'Schema [audit] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [audit] ja existe.';
END
GO

-- ========================================
-- 5. SCHEMA: ctl (Controle ETL)
-- ========================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
BEGIN
    EXEC('CREATE SCHEMA ctl AUTHORIZATION dbo');
    PRINT 'Schema [ctl] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [ctl] ja existe.';
END
GO

-- ========================================
-- 6. VALIDACAO
-- ========================================
PRINT '';
PRINT '========================================';
PRINT 'VALIDACAO DOS SCHEMAS';
PRINT '========================================';

SELECT
    schema_id AS [id],
    name AS [schema_name],
    USER_NAME(principal_id) AS [owner_name]
FROM sys.schemas
WHERE name IN ('dim', 'fact', 'stg', 'audit', 'ctl')
ORDER BY name;

PRINT '';
PRINT 'Schemas criados com sucesso.';
PRINT '';
PRINT '========================================';
PRINT 'PROXIMO PASSO: Execute 03_configure_database.sql';
PRINT '========================================';
GO

