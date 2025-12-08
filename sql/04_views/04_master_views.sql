-- ========================================
-- SCRIPT: _master_views.sql
-- DESCRIÇÃO: Script master que executa todas as views em ordem
-- AUTOR: Igor Natan
-- DATA: 2025-12-06
-- ========================================

PRINT '========================================';
PRINT 'EXECUÇÃO DE TODAS AS VIEWS';
PRINT 'Data Warehouse E-commerce';
PRINT '========================================';
PRINT '';

-- 1. View Calendário
PRINT '1/3 Executando: 01_vw_calendario_completo.sql';
:r .\01_vw_calendario_completo.sql
PRINT '';

-- 2. View Produtos
PRINT '2/3 Executando: 02_vw_produtos_ativos.sql';
:r .\02_vw_produtos_ativos.sql
PRINT '';

-- 3. View Geografia
PRINT '3/3 Executando: 03_vw_hierarquia_geografica.sql';
:r .\03_vw_hierarquia_geografica.sql
PRINT '';

PRINT '========================================';
PRINT '✅ TODAS AS VIEWS CRIADAS COM SUCESSO!';
PRINT '========================================';
PRINT '';

-- Validação final
PRINT 'Validação: Listando views criadas';
SELECT 
    s.name AS schema_name,
    v.name AS view_name,
    v.create_date,
    v.modify_date
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE s.name = 'dim'
ORDER BY v.name;
GO