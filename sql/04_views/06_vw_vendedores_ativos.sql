IF OBJECT_ID('dim.VW_VENDEDORES_ATIVOS', 'V') IS NOT NULL
    DROP VIEW dim.VW_VENDEDORES_ATIVOS;
GO

CREATE VIEW dim.VW_VENDEDORES_ATIVOS
AS
SELECT 
    v.vendedor_id,
    v.vendedor_original_id,
    v.nome_vendedor,
    v.nome_exibicao,
    v.email,
    v.cargo,
    v.nivel_senioridade,
    -- Equipe
    v.equipe_id,
    v.nome_equipe,
    e.regional,
    e.tipo_equipe,
    -- Hierarquia
    v.gerente_id,
    v.nome_gerente,
    v.eh_lider,
    -- Localização
    v.estado_atuacao,
    v.cidade_atuacao,
    v.tipo_vendedor,
    -- Metas
    v.meta_mensal_base,
    v.percentual_comissao_padrao,
    -- Temporal
    v.data_contratacao,
    DATEDIFF(MONTH, v.data_contratacao, GETDATE()) AS meses_na_empresa,
    -- Classificação
    CASE 
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 6 THEN 'Novato (<6m)'
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 12 THEN 'Júnior (6-12m)'
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 24 THEN 'Intermediário (1-2a)'
        ELSE 'Veterano (2a+)'
    END AS tempo_casa_categoria
FROM dim.DIM_VENDEDOR v
LEFT JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
WHERE v.eh_ativo = 1 AND v.situacao = 'Ativo';
GO

PRINT '✅ View dim.VW_VENDEDORES_ATIVOS criada!';