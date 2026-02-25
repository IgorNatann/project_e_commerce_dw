-- ========================================
-- SCRIPT: 02_create_schemas.sql
-- OBJETIVO: criar schemas OLTP
-- ========================================

USE ECOMMERCE_OLTP;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
BEGIN
    EXEC('CREATE SCHEMA core');
    PRINT 'Schema core criado.';
END
ELSE
BEGIN
    PRINT 'Schema core ja existe.';
END;
GO
