-- ========================================
-- SCRIPT: 01_create_schema_ctl.sql
-- OBJETIVO: criar schema ctl para controle operacional de ETL
-- ========================================

USE DW_ECOMMERCE;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
BEGIN
    EXEC('CREATE SCHEMA ctl AUTHORIZATION dbo');
    PRINT 'Schema ctl criado.';
END
ELSE
BEGIN
    PRINT 'Schema ctl ja existe.';
END;
GO
