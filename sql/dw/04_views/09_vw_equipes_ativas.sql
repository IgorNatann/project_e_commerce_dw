IF OBJECT_ID('dim.VW_EQUIPES_ATIVAS', 'V') IS NOT NULL
    DROP VIEW dim.VW_EQUIPES_ATIVAS;
GO

CREATE VIEW dim.VW_EQUIPES_ATIVAS
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_EQUIPES_ATIVAS                                               ║
║  Propósito: Facilitar queries mostrando apenas equipes operacionais   ║
║  Uso: SELECT * FROM dim.VW_EQUIPES_ATIVAS WHERE regional = 'Sul'      ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    equipe_id,
    equipe_original_id,
    nome_equipe,
    codigo_equipe,
    tipo_equipe,
    categoria_equipe,
    regional,
    estado_sede,
    cidade_sede,
    -- Metas
    meta_mensal_equipe,
    meta_trimestral_equipe,
    meta_anual_equipe,
    qtd_meta_vendas_mes,
    -- Composição
    qtd_membros_atual,
    qtd_membros_ideal,
    qtd_membros_ideal - qtd_membros_atual AS vagas_em_aberto,
    -- Meta per capita
    CASE 
        WHEN qtd_membros_atual > 0 
        THEN meta_mensal_equipe / qtd_membros_atual
        ELSE NULL 
    END AS meta_mensal_per_capita,
    -- Classificação de porte
    CASE 
        WHEN qtd_membros_atual >= 10 THEN 'Grande (10+)'
        WHEN qtd_membros_atual >= 5 THEN 'Média (5-9)'
        WHEN qtd_membros_atual >= 1 THEN 'Pequena (1-4)'
        ELSE 'Vazia (0)'
    END AS porte_equipe,
    -- Liderança
    lider_equipe_id,
    nome_lider,
    email_lider,
    -- Datas
    data_criacao,
    DATEDIFF(MONTH, data_criacao, GETDATE()) AS meses_ativa
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa';
GO

PRINT '✅ View dim.VW_EQUIPES_ATIVAS criada!';