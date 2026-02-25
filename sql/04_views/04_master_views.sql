-- ========================================
-- SCRIPT: 04_master_views.sql
-- DESCRIÇÃO: Script master que executa todas as views auxiliares em ordem
-- AUTOR: Igor Natan
-- DATA: 2026-02-25
-- OBS: Execute em SQLCMD Mode (usa comando :r)
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'EXECUÇÃO MASTER DAS VIEWS AUXILIARES';
PRINT 'Data Warehouse E-commerce';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. Views Dimensionais
-- ========================================
PRINT '1/10 Executando: 01_vw_calendario_completo.sql';
:r .\01_vw_calendario_completo.sql
PRINT '';

PRINT '2/10 Executando: 02_vw_produtos_ativos.sql';
:r .\02_vw_produtos_ativos.sql
PRINT '';

PRINT '3/10 Executando: 03_vw_hierarquia_geografica.sql';
:r .\03_vw_hierarquia_geografica.sql
PRINT '';

PRINT '4/10 Executando: 05_vw_descontos_ativos.sql';
:r .\05_vw_descontos_ativos.sql
PRINT '';

PRINT '5/10 Executando: 06_vw_vendedores_ativos.sql';
:r .\06_vw_vendedores_ativos.sql
PRINT '';

PRINT '6/10 Executando: 07_vw_hierarquia_vendedores.sql';
:r .\07_vw_hierarquia_vendedores.sql
PRINT '';

-- ========================================
-- 2. Views de Equipes
-- ========================================
PRINT '7/10 Executando: 08_dw_analise_equipe_vendedores.sql';
:r .\08_dw_analise_equipe_vendedores.sql
PRINT '';

PRINT '8/10 Executando: 09_vw_equipes_ativas.sql';
:r .\09_vw_equipes_ativas.sql
PRINT '';

PRINT '9/10 Executando: 10_vw_ranking_equipes_meta.sql';
:r .\10_vw_ranking_equipes_meta.sql
PRINT '';

PRINT '10/10 Executando: 11_vw_analise_regional_equipes.sql';
:r .\11_vw_analise_regional_equipes.sql
PRINT '';

PRINT '========================================';
PRINT 'VALIDAÇÃO FINAL';
PRINT '========================================';
PRINT '';

;WITH expected_views AS (
    SELECT 'VW_CALENDARIO_COMPLETO' AS view_name UNION ALL
    SELECT 'VW_PRODUTOS_ATIVOS' UNION ALL
    SELECT 'VW_HIERARQUIA_GEOGRAFICA' UNION ALL
    SELECT 'VW_DESCONTOS_ATIVOS' UNION ALL
    SELECT 'VW_VENDEDORES_ATIVOS' UNION ALL
    SELECT 'VW_HIERARQUIA_VENDEDORES' UNION ALL
    SELECT 'VW_ANALISE_EQUIPE_VENDEDORES' UNION ALL
    SELECT 'VW_EQUIPES_ATIVAS' UNION ALL
    SELECT 'VW_RANKING_EQUIPES_META' UNION ALL
    SELECT 'VW_ANALISE_REGIONAL_EQUIPES'
)
SELECT
    'dim' AS schema_name,
    ev.view_name,
    CASE WHEN v.object_id IS NULL THEN 'MISSING' ELSE 'OK' END AS status,
    v.modify_date
FROM expected_views ev
LEFT JOIN sys.views v
    ON v.name = ev.view_name
   AND SCHEMA_NAME(v.schema_id) = 'dim'
ORDER BY ev.view_name;

IF EXISTS (
    SELECT 1
    FROM (
        SELECT 'VW_CALENDARIO_COMPLETO' AS view_name UNION ALL
        SELECT 'VW_PRODUTOS_ATIVOS' UNION ALL
        SELECT 'VW_HIERARQUIA_GEOGRAFICA' UNION ALL
        SELECT 'VW_DESCONTOS_ATIVOS' UNION ALL
        SELECT 'VW_VENDEDORES_ATIVOS' UNION ALL
        SELECT 'VW_HIERARQUIA_VENDEDORES' UNION ALL
        SELECT 'VW_ANALISE_EQUIPE_VENDEDORES' UNION ALL
        SELECT 'VW_EQUIPES_ATIVAS' UNION ALL
        SELECT 'VW_RANKING_EQUIPES_META' UNION ALL
        SELECT 'VW_ANALISE_REGIONAL_EQUIPES'
    ) e
    LEFT JOIN sys.views v
        ON v.name = e.view_name
       AND SCHEMA_NAME(v.schema_id) = 'dim'
    WHERE v.object_id IS NULL
)
BEGIN
    THROW 51000, 'Falha na validação: nem todas as views auxiliares foram criadas.', 1;
END;

PRINT '';
PRINT '✅ MASTER VIEWS EXECUTADO COM SUCESSO!';
PRINT '✅ 10/10 views auxiliares validadas.';
PRINT '';
GO
