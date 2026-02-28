-- ========================================
-- SCRIPT: 14_vw_dash_descontos_r1.sql
-- OBJETIVO: camada de consumo para dashboard de descontos/ROI R1
-- ========================================

USE DW_ECOMMERCE;
GO

CREATE OR ALTER VIEW fact.VW_DASH_DESCONTOS_R1
AS
SELECT
    fd.desconto_aplicado_id,
    fd.desconto_aplicado_original_id,
    fd.venda_id,
    fv.venda_original_id,
    fd.numero_pedido,
    fd.data_aplicacao_id,
    d.data_completa,
    d.ano,
    d.trimestre,
    d.mes,
    d.nome_mes,
    fd.desconto_id,
    dd.desconto_original_id,
    dd.codigo_desconto,
    dd.nome_campanha,
    dd.tipo_desconto,
    dd.metodo_desconto,
    COALESCE(dd.origem_campanha, 'Nao informado') AS origem_campanha,
    COALESCE(dd.canal_divulgacao, 'Nao informado') AS canal_divulgacao,
    fd.cliente_id,
    c.nome_cliente,
    c.tipo_cliente,
    c.segmento,
    fd.produto_id,
    p.nome_produto,
    p.categoria,
    p.subcategoria,
    p.marca,
    fv.regiao_id,
    r.estado,
    r.cidade,
    r.regiao_pais,
    fv.vendedor_id,
    v.nome_vendedor,
    v.nome_equipe,
    fd.nivel_aplicacao,
    CAST(fd.valor_sem_desconto AS decimal(15, 2)) AS valor_sem_desconto,
    CAST(fd.valor_desconto_aplicado AS decimal(15, 2)) AS valor_desconto_aplicado,
    CAST(fd.valor_com_desconto AS decimal(15, 2)) AS valor_com_desconto,
    CAST(fd.percentual_desconto_efetivo AS decimal(8, 2)) AS percentual_desconto_efetivo,
    CAST(fd.margem_antes_desconto AS decimal(15, 2)) AS margem_antes_desconto,
    CAST(fd.margem_apos_desconto AS decimal(15, 2)) AS margem_apos_desconto,
    CAST(fd.impacto_margem AS decimal(15, 2)) AS impacto_margem,
    CASE
        WHEN fd.margem_apos_desconto < 0 THEN 'Prejuizo'
        WHEN fd.margem_antes_desconto IS NOT NULL
             AND fd.margem_apos_desconto < (fd.margem_antes_desconto * 0.3) THEN 'Margem critica'
        WHEN fd.margem_antes_desconto IS NOT NULL
             AND fd.margem_apos_desconto < (fd.margem_antes_desconto * 0.6) THEN 'Margem reduzida'
        ELSE 'Margem saudavel'
    END AS status_margem,
    fd.desconto_aprovado,
    fd.motivo_rejeicao,
    CAST(
        CASE
            WHEN fd.valor_desconto_aplicado > 0
                THEN (fd.valor_com_desconto - fd.valor_desconto_aplicado) / fd.valor_desconto_aplicado
            ELSE 0
        END AS decimal(12, 4)
    ) AS roi_desconto,
    CAST(
        CASE
            WHEN fd.valor_com_desconto > 0
                THEN fd.impacto_margem / fd.valor_com_desconto
            ELSE 0
        END AS decimal(12, 4)
    ) AS impacto_margem_pct_receita,
    fd.data_inclusao,
    fd.data_atualizacao
FROM fact.FACT_DESCONTOS AS fd
INNER JOIN dim.DIM_DESCONTO AS dd
    ON dd.desconto_id = fd.desconto_id
INNER JOIN dim.DIM_DATA AS d
    ON d.data_id = fd.data_aplicacao_id
INNER JOIN dim.DIM_CLIENTE AS c
    ON c.cliente_id = fd.cliente_id
INNER JOIN fact.FACT_VENDAS AS fv
    ON fv.venda_id = fd.venda_id
LEFT JOIN dim.DIM_PRODUTO AS p
    ON p.produto_id = fd.produto_id
LEFT JOIN dim.DIM_REGIAO AS r
    ON r.regiao_id = fv.regiao_id
LEFT JOIN dim.DIM_VENDEDOR AS v
    ON v.vendedor_id = fv.vendedor_id;
GO

PRINT 'View fact.VW_DASH_DESCONTOS_R1 pronta para consumo.';
GO
