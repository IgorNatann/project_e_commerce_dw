IF OBJECT_ID('dim.VW_ANALISE_EQUIPE_VENDEDORES', 'V') IS NOT NULL
    DROP VIEW dim.VW_ANALISE_EQUIPE_VENDEDORES;
GO

CREATE VIEW dim.VW_ANALISE_EQUIPE_VENDEDORES
AS
SELECT 
    e.equipe_id,
    e.nome_equipe,
    e.tipo_equipe,
    e.regional,
    -- Contagens
    COUNT(v.vendedor_id) AS total_vendedores,
    SUM(CASE WHEN v.eh_lider = 1 THEN 1 ELSE 0 END) AS total_lideres,
    -- Metas
    SUM(v.meta_mensal_base) AS soma_metas_individuais,
    AVG(v.meta_mensal_base) AS media_meta_por_vendedor,
    e.meta_mensal_equipe AS meta_oficial_equipe,
    -- Comparação
    e.meta_mensal_equipe - SUM(v.meta_mensal_base) AS diferenca_metas,
    -- Senioridade
    SUM(CASE WHEN v.nivel_senioridade = 'Júnior' THEN 1 ELSE 0 END) AS juniors,
    SUM(CASE WHEN v.nivel_senioridade = 'Pleno' THEN 1 ELSE 0 END) AS plenos,
    SUM(CASE WHEN v.nivel_senioridade IN ('Sênior', 'Especialista', 'Gerente') THEN 1 ELSE 0 END) AS seniors
FROM dim.DIM_EQUIPE e
LEFT JOIN dim.DIM_VENDEDOR v ON e.equipe_id = v.equipe_id AND v.eh_ativo = 1
WHERE e.eh_ativa = 1
GROUP BY e.equipe_id, e.nome_equipe, e.tipo_equipe, e.regional, e.meta_mensal_equipe;
GO

PRINT '✅ View dim.VW_ANALISE_EQUIPE_VENDEDORES criada!';
PRINT '';