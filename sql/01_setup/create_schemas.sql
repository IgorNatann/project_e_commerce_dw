-- ========================================
-- SCRIPT: 02_create_schemas.sql
-- DESCRIÇÃO: Criação dos schemas organizacionais
-- AUTOR: Igor
-- DATA: 2025-12-01
-- PRÉ-REQUISITO: 01_create_database.sql
-- ========================================

-- ========================================
-- 1. USAR DATABASE
-- ========================================
USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DOS SCHEMAS';
PRINT '========================================';
PRINT '';

-- ========================================
-- 2. SCHEMA: dim (Dimensões)
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim')
BEGIN
    EXEC('CREATE SCHEMA dim AUTHORIZATION dbo');
    PRINT '✅ Schema [dim] criado para tabelas DIMENSÃO.';
END
ELSE
BEGIN
    PRINT 'ℹ️  Schema [dim] já existe.';
END
GO

-- ========================================
-- 3. SCHEMA: fact (Fatos)
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact')
BEGIN
    EXEC('CREATE SCHEMA fact AUTHORIZATION dbo');
    PRINT '✅ Schema [fact] criado para tabelas FATO.';
END
ELSE
BEGIN
    PRINT 'ℹ️  Schema [fact] já existe.';
END
GO

-- ========================================
-- 4. SCHEMA: stg (Staging)
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo');
    PRINT '✅ Schema [stg] criado para área de STAGING (ETL).';
END
ELSE
BEGIN
    PRINT 'ℹ️  Schema [stg] já existe.';
END
GO

-- ========================================
-- 5. SCHEMA: audit (Auditoria)
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo');
    PRINT '✅ Schema [audit] criado para tabelas de AUDITORIA.';
END
ELSE
BEGIN
    PRINT 'ℹ️  Schema [audit] já existe.';
END
GO

-- ========================================
-- 6. VALIDAÇÃO
-- ========================================
PRINT '';
PRINT '========================================';
PRINT 'VALIDAÇÃO DOS SCHEMAS';
PRINT '========================================';

SELECT 
    schema_id AS [ID],
    name AS [Schema],
    USER_NAME(principal_id) AS [Owner]
FROM sys.schemas
WHERE name IN ('dim', 'fact', 'stg', 'audit')
ORDER BY name;

PRINT '';
PRINT '✅ Schemas criados com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO: Execute 03_configure_database.sql';
PRINT '========================================';