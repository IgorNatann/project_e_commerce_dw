-- ========================================
-- SCRIPT: 02_create_schemas.sql
-- OBJETIVO: criacao dos schemas organizacionais no DW
-- PRE-REQUISITO: 01_create_database.sql
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIACAO DOS SCHEMAS';
PRINT '========================================';
PRINT '';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
BEGIN
    EXEC('CREATE SCHEMA dim AUTHORIZATION dbo');
    PRINT 'Schema [dim] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [dim] ja existe.';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
BEGIN
    EXEC('CREATE SCHEMA fact AUTHORIZATION dbo');
    PRINT 'Schema [fact] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [fact] ja existe.';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo');
    PRINT 'Schema [stg] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [stg] ja existe.';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo');
    PRINT 'Schema [audit] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [audit] ja existe.';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
BEGIN
    EXEC('CREATE SCHEMA ctl AUTHORIZATION dbo');
    PRINT 'Schema [ctl] criado.';
END
ELSE
BEGIN
    PRINT 'Schema [ctl] ja existe.';
END;
GO

PRINT '';
PRINT '========================================';
PRINT 'VALIDACAO DOS SCHEMAS';
PRINT '========================================';

SELECT
    schema_id AS schema_id,
    name AS schema_name,
    USER_NAME(principal_id) AS schema_owner
FROM sys.schemas
WHERE name IN ('dim', 'fact', 'stg', 'audit', 'ctl')
ORDER BY name;

PRINT '';
PRINT 'Schemas criados com sucesso.';
PRINT 'Proximo passo: execute 03_configure_database.sql';
GO
