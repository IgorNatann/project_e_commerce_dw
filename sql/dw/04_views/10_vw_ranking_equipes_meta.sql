IF OBJECT_ID('dim.VW_RANKING_EQUIPES_META', 'V') IS NOT NULL
    DROP VIEW dim.VW_RANKING_EQUIPES_META;
GO

CREATE VIEW dim.VW_RANKING_EQUIPES_META
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_RANKING_EQUIPES_META                                         ║
║  Propósito: Mostrar ranking das equipes por meta mensal               ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    ROW_NUMBER() OVER (ORDER BY meta_mensal_equipe DESC) AS ranking_geral,
    ROW_NUMBER() OVER (PARTITION BY regional ORDER BY meta_mensal_equipe DESC) AS ranking_regional,
    equipe_id,
    nome_equipe,
    tipo_equipe,
    regional,
    meta_mensal_equipe,
    qtd_membros_atual,
    CASE 
        WHEN qtd_membros_atual > 0 
        THEN meta_mensal_equipe / qtd_membros_atual
        ELSE NULL 
    END AS meta_per_capita,
    -- Classificação
    CASE 
        WHEN meta_mensal_equipe >= 500000 THEN 'Top (500k+)'
        WHEN meta_mensal_equipe >= 300000 THEN 'Alto (300k-500k)'
        WHEN meta_mensal_equipe >= 150000 THEN 'Médio (150k-300k)'
        ELSE 'Baixo (<150k)'
    END AS faixa_meta
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa';
GO

PRINT '✅ View dim.VW_RANKING_EQUIPES_META criada!';