-- ========================================
-- SCRIPT: 02_create_schemas.sql
-- PURPOSE: Create OLTP schemas
-- ========================================

USE ECOMMERCE_OLTP;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = ''core'')
    EXEC(''CREATE SCHEMA core'');
GO

PRINT ''Schemas ready (core).'';
GO