-- ========================================
-- SCRIPT: 01_schema_checks.sql
-- OBJETIVO: validacao basica do schema OLTP
-- ========================================

USE ECOMMERCE_OLTP;
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'VALIDACAO SCHEMA OLTP';
PRINT '========================================';
PRINT '';

;WITH expected_tables AS (
    SELECT 'regions' AS table_name UNION ALL
    SELECT 'teams' UNION ALL
    SELECT 'suppliers' UNION ALL
    SELECT 'customers' UNION ALL
    SELECT 'products' UNION ALL
    SELECT 'sellers' UNION ALL
    SELECT 'discount_campaigns' UNION ALL
    SELECT 'orders' UNION ALL
    SELECT 'order_items' UNION ALL
    SELECT 'order_item_discounts' UNION ALL
    SELECT 'seller_targets_monthly'
)
SELECT
    e.table_name,
    CASE WHEN t.object_id IS NULL THEN 'MISSING' ELSE 'OK' END AS status,
    t.create_date
FROM expected_tables e
LEFT JOIN sys.tables t
    ON t.name = e.table_name
   AND SCHEMA_NAME(t.schema_id) = 'core'
ORDER BY e.table_name;

PRINT '';
PRINT 'Resumo de objetos:';
SELECT
    (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('core')) AS total_tabelas_core,
    (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN (SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID('core'))) AS total_fks_core,
    (SELECT COUNT(*) FROM sys.indexes WHERE object_id IN (SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID('core')) AND type_desc <> 'HEAP') AS total_indices_core;
GO
