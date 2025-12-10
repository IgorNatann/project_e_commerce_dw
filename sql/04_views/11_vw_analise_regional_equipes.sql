IF OBJECT_ID('dim.VW_ANALISE_REGIONAL_EQUIPES', 'V') IS NOT NULL
    DROP VIEW dim.VW_ANALISE_REGIONAL_EQUIPES;
GO

CREATE VIEW dim.VW_ANALISE_REGIONAL_EQUIPES
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_ANALISE_REGIONAL_EQUIPES                                     ║
║  Propósito: Agregação por regional para dashboards executivos         ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    regional,
    COUNT(*) AS total_equipes,
    SUM(qtd_membros_atual) AS total_vendedores,
    SUM(meta_mensal_equipe) AS meta_mensal_regional,
    AVG(meta_mensal_equipe) AS meta_media_por_equipe,
    MIN(meta_mensal_equipe) AS menor_meta,
    MAX(meta_mensal_equipe) AS maior_meta,
    -- Meta per capita regional
    SUM(meta_mensal_equipe) / NULLIF(SUM(qtd_membros_atual), 0) AS meta_per_capita_regional,
    -- Distribuição por tipo
    SUM(CASE WHEN tipo_equipe = 'Vendas Diretas' THEN 1 ELSE 0 END) AS equipes_diretas,
    SUM(CASE WHEN tipo_equipe = 'Inside Sales' THEN 1 ELSE 0 END) AS equipes_inside,
    SUM(CASE WHEN tipo_equipe = 'Key Accounts' THEN 1 ELSE 0 END) AS equipes_key_accounts,
    SUM(CASE WHEN tipo_equipe = 'E-commerce' THEN 1 ELSE 0 END) AS equipes_ecommerce
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa'
GROUP BY regional;
GO

PRINT '✅ View dim.VW_ANALISE_REGIONAL_EQUIPES criada!';
PRINT '';