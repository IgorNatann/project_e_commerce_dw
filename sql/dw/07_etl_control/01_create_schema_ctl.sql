-- ========================================
-- SCRIPT: 01_create_schema_ctl.sql
-- OBJETIVO: criar schema de controle do ETL
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'CRIACAO DO SCHEMA [ctl]';
PRINT '========================================';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
BEGIN
    EXEC('CREATE SCHEMA ctl AUTHORIZATION dbo');
    PRINT 'Schema [ctl] criado com sucesso.';
END
ELSE
BEGIN
    PRINT 'Schema [ctl] ja existe.';
END
GO

SELECT
    schema_id AS id,
    name AS schema_name,
    USER_NAME(principal_id) AS owner_name
FROM sys.schemas
WHERE name = 'ctl';
GO

