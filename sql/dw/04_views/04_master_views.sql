-- ========================================
-- SCRIPT: 04_master_views.sql
-- DESCRICAO: executa todas as views auxiliares em ordem
-- OBS: executar em SQLCMD Mode (usa comando :r)
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'EXECUCAO MASTER DAS VIEWS AUXILIARES';
PRINT 'Data Warehouse E-commerce';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. Views dimensionais
-- ========================================
PRINT '1/12 Executando: 01_vw_calendario_completo.sql';
:r .\01_vw_calendario_completo.sql
PRINT '';

PRINT '2/12 Executando: 02_vw_produtos_ativos.sql';
:r .\02_vw_produtos_ativos.sql
PRINT '';

PRINT '3/12 Executando: 03_vw_hierarquia_geografica.sql';
:r .\03_vw_hierarquia_geografica.sql
PRINT '';

PRINT '4/12 Executando: 05_vw_descontos_ativos.sql';
:r .\05_vw_descontos_ativos.sql
PRINT '';

PRINT '5/12 Executando: 06_vw_vendedores_ativos.sql';
:r .\06_vw_vendedores_ativos.sql
PRINT '';

PRINT '6/12 Executando: 07_vw_hierarquia_vendedores.sql';
:r .\07_vw_hierarquia_vendedores.sql
PRINT '';

-- ========================================
-- 2. Views de equipes
-- ========================================
PRINT '7/12 Executando: 08_dw_analise_equipe_vendedores.sql';
:r .\08_dw_analise_equipe_vendedores.sql
PRINT '';

PRINT '8/12 Executando: 09_vw_equipes_ativas.sql';
:r .\09_vw_equipes_ativas.sql
PRINT '';

PRINT '9/12 Executando: 10_vw_ranking_equipes_meta.sql';
:r .\10_vw_ranking_equipes_meta.sql
PRINT '';

PRINT '10/12 Executando: 11_vw_analise_regional_equipes.sql';
:r .\11_vw_analise_regional_equipes.sql
PRINT '';

-- ========================================
-- 3. View de consumo para dashboard
-- ========================================
PRINT '11/12 Executando: 12_vw_dash_vendas_r1.sql';
:r .\12_vw_dash_vendas_r1.sql
PRINT '';

PRINT '12/12 Executando: 13_vw_dash_metas_r1.sql';
:r .\13_vw_dash_metas_r1.sql
PRINT '';

PRINT '========================================';
PRINT 'VALIDACAO FINAL';
PRINT '========================================';
PRINT '';

;WITH expected_views AS (
    SELECT 'dim' AS schema_name, 'VW_CALENDARIO_COMPLETO' AS view_name UNION ALL
    SELECT 'dim', 'VW_PRODUTOS_ATIVOS' UNION ALL
    SELECT 'dim', 'VW_HIERARQUIA_GEOGRAFICA' UNION ALL
    SELECT 'dim', 'VW_DESCONTOS_ATIVOS' UNION ALL
    SELECT 'dim', 'VW_VENDEDORES_ATIVOS' UNION ALL
    SELECT 'dim', 'VW_HIERARQUIA_VENDEDORES' UNION ALL
    SELECT 'dim', 'VW_ANALISE_EQUIPE_VENDEDORES' UNION ALL
    SELECT 'dim', 'VW_EQUIPES_ATIVAS' UNION ALL
    SELECT 'dim', 'VW_RANKING_EQUIPES_META' UNION ALL
    SELECT 'dim', 'VW_ANALISE_REGIONAL_EQUIPES' UNION ALL
    SELECT 'fact', 'VW_DASH_VENDAS_R1' UNION ALL
    SELECT 'fact', 'VW_DASH_METAS_R1'
)
SELECT
    ev.schema_name,
    ev.view_name,
    CASE WHEN v.object_id IS NULL THEN 'MISSING' ELSE 'OK' END AS status,
    v.modify_date
FROM expected_views ev
LEFT JOIN sys.views v
    ON v.name = ev.view_name
   AND SCHEMA_NAME(v.schema_id) = ev.schema_name
ORDER BY ev.schema_name, ev.view_name;

IF EXISTS (
    SELECT 1
    FROM (
        SELECT 'dim' AS schema_name, 'VW_CALENDARIO_COMPLETO' AS view_name UNION ALL
        SELECT 'dim', 'VW_PRODUTOS_ATIVOS' UNION ALL
        SELECT 'dim', 'VW_HIERARQUIA_GEOGRAFICA' UNION ALL
        SELECT 'dim', 'VW_DESCONTOS_ATIVOS' UNION ALL
        SELECT 'dim', 'VW_VENDEDORES_ATIVOS' UNION ALL
        SELECT 'dim', 'VW_HIERARQUIA_VENDEDORES' UNION ALL
        SELECT 'dim', 'VW_ANALISE_EQUIPE_VENDEDORES' UNION ALL
        SELECT 'dim', 'VW_EQUIPES_ATIVAS' UNION ALL
        SELECT 'dim', 'VW_RANKING_EQUIPES_META' UNION ALL
        SELECT 'dim', 'VW_ANALISE_REGIONAL_EQUIPES' UNION ALL
        SELECT 'fact', 'VW_DASH_VENDAS_R1' UNION ALL
        SELECT 'fact', 'VW_DASH_METAS_R1'
    ) e
    LEFT JOIN sys.views v
        ON v.name = e.view_name
       AND SCHEMA_NAME(v.schema_id) = e.schema_name
    WHERE v.object_id IS NULL
)
BEGIN
    THROW 51000, 'Falha na validacao: nem todas as views foram criadas.', 1;
END;

PRINT '';
PRINT 'Views auxiliares executadas com sucesso.';
PRINT '';
GO
