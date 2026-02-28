-- ========================================
-- SCRIPT: 12_vw_dash_vendas_r1.sql
-- OBJETIVO: camada de consumo para dashboard de vendas R1
-- ========================================

USE DW_ECOMMERCE;
GO

CREATE OR ALTER VIEW fact.VW_DASH_VENDAS_R1
AS
SELECT
    fv.venda_id,
    fv.venda_original_id,
    fv.numero_pedido,
    fv.data_id,
    d.data_completa,
    d.ano,
    d.trimestre,
    d.mes,
    d.nome_mes,
    fv.cliente_id,
    c.nome_cliente,
    c.tipo_cliente,
    c.segmento,
    fv.produto_id,
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
    fv.quantidade_vendida,
    fv.preco_unitario_tabela,
    fv.valor_total_bruto,
    fv.valor_total_descontos,
    fv.valor_total_liquido,
    fv.custo_total,
    fv.valor_total_liquido - fv.custo_total AS margem_bruta,
    fv.quantidade_devolvida,
    fv.valor_devolvido,
    fv.percentual_comissao,
    fv.valor_comissao,
    fv.teve_desconto,
    fv.data_inclusao,
    fv.data_atualizacao
FROM fact.FACT_VENDAS AS fv
INNER JOIN dim.DIM_DATA AS d ON d.data_id = fv.data_id
INNER JOIN dim.DIM_CLIENTE AS c ON c.cliente_id = fv.cliente_id
INNER JOIN dim.DIM_PRODUTO AS p ON p.produto_id = fv.produto_id
INNER JOIN dim.DIM_REGIAO AS r ON r.regiao_id = fv.regiao_id
LEFT JOIN dim.DIM_VENDEDOR AS v ON v.vendedor_id = fv.vendedor_id;
GO

PRINT 'View fact.VW_DASH_VENDAS_R1 pronta para consumo.';
GO
