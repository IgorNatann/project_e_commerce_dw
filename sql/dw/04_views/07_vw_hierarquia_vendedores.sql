IF OBJECT_ID('dim.VW_HIERARQUIA_VENDEDORES', 'V') IS NOT NULL
    DROP VIEW dim.VW_HIERARQUIA_VENDEDORES;
GO

CREATE VIEW dim.VW_HIERARQUIA_VENDEDORES
AS
SELECT 
    v.vendedor_id,
    v.nome_vendedor,
    v.cargo,
    v.nivel_senioridade,
    v.equipe_id,
    v.nome_equipe,
    -- Gerente Direto
    v.gerente_id AS gerente_direto_id,
    g1.nome_vendedor AS gerente_direto_nome,
    g1.cargo AS gerente_direto_cargo,
    -- Gerente do Gerente (2º nível)
    g1.gerente_id AS gerente_nivel2_id,
    g2.nome_vendedor AS gerente_nivel2_nome,
    -- Nível hierárquico
    CASE 
        WHEN v.gerente_id IS NULL THEN 1
        WHEN g1.gerente_id IS NULL THEN 2
        WHEN g2.gerente_id IS NULL THEN 3
        ELSE 4
    END AS nivel_hierarquico,
    v.eh_lider,
    v.eh_ativo
FROM dim.DIM_VENDEDOR v
LEFT JOIN dim.DIM_VENDEDOR g1 ON v.gerente_id = g1.vendedor_id
LEFT JOIN dim.DIM_VENDEDOR g2 ON g1.gerente_id = g2.vendedor_id;
GO

PRINT '✅ View dim.VW_HIERARQUIA_VENDEDORES criada!';