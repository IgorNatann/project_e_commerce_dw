-- ========================================
-- SCRIPT: 13_vw_dash_metas_r1.sql
-- OBJETIVO: camada de consumo para dashboard de metas/atingimento R1
-- ========================================

USE DW_ECOMMERCE;
GO

CREATE OR ALTER VIEW fact.VW_DASH_METAS_R1
AS
WITH month_range AS
(
    SELECT
        d.data_id,
        CAST(d.data_completa AS date) AS data_completa,
        d.ano,
        d.trimestre,
        d.mes,
        d.nome_mes
    FROM dim.DIM_DATA AS d
    WHERE d.dia = 1
      AND d.data_completa >= DATEADD(month, -24, CAST(GETDATE() AS date))
      AND d.data_completa <= EOMONTH(CAST(GETDATE() AS date))
),
sellers AS
(
    SELECT
        v.vendedor_id,
        v.vendedor_original_id,
        v.nome_vendedor,
        COALESCE(v.nome_equipe, 'Sem equipe') AS nome_equipe,
        v.equipe_id,
        COALESCE(e.regional, 'Sem regional') AS regional,
        COALESCE(e.tipo_equipe, 'Nao informado') AS tipo_equipe,
        COALESCE(v.estado_atuacao, 'Nao informado') AS estado_atuacao,
        COALESCE(v.cidade_atuacao, 'Nao informado') AS cidade_atuacao,
        COALESCE(v.meta_mensal_base, 0.0) AS valor_meta
    FROM dim.DIM_VENDEDOR AS v
    LEFT JOIN dim.DIM_EQUIPE AS e
        ON e.equipe_id = v.equipe_id
    WHERE v.eh_ativo = 1
      AND v.situacao = 'Ativo'
),
sales_monthly AS
(
    SELECT
        DATEFROMPARTS(d.ano, d.mes, 1) AS data_completa,
        fv.vendedor_id,
        SUM(fv.valor_total_liquido) AS valor_realizado,
        SUM(fv.quantidade_vendida) AS itens_realizados,
        COUNT(DISTINCT fv.numero_pedido) AS pedidos_realizados
    FROM fact.FACT_VENDAS AS fv
    INNER JOIN dim.DIM_DATA AS d
        ON d.data_id = fv.data_id
    GROUP BY
        DATEFROMPARTS(d.ano, d.mes, 1),
        fv.vendedor_id
),
base AS
(
    SELECT
        mr.data_id,
        mr.data_completa,
        mr.ano,
        mr.trimestre,
        mr.mes,
        mr.nome_mes,
        s.vendedor_id,
        s.vendedor_original_id,
        s.nome_vendedor,
        s.nome_equipe,
        s.equipe_id,
        s.regional,
        s.tipo_equipe,
        s.estado_atuacao,
        s.cidade_atuacao,
        s.valor_meta,
        COALESCE(sm.valor_realizado, 0.0) AS valor_realizado,
        COALESCE(sm.itens_realizados, 0) AS itens_realizados,
        COALESCE(sm.pedidos_realizados, 0) AS pedidos_realizados
    FROM month_range AS mr
    CROSS JOIN sellers AS s
    LEFT JOIN sales_monthly AS sm
        ON sm.data_completa = mr.data_completa
       AND sm.vendedor_id = s.vendedor_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY b.data_id, b.vendedor_id) AS meta_snapshot_id,
    b.data_id,
    b.data_completa,
    b.ano,
    b.trimestre,
    b.mes,
    b.nome_mes,
    b.vendedor_id,
    b.vendedor_original_id,
    b.nome_vendedor,
    b.nome_equipe,
    b.equipe_id,
    b.regional,
    b.tipo_equipe,
    b.estado_atuacao,
    b.cidade_atuacao,
    CAST(b.valor_meta AS decimal(15, 2)) AS valor_meta,
    CAST(b.valor_realizado AS decimal(15, 2)) AS valor_realizado,
    CAST(b.valor_realizado - b.valor_meta AS decimal(15, 2)) AS gap_meta,
    CAST(
        CASE
            WHEN b.valor_meta > 0 THEN (b.valor_realizado / b.valor_meta) * 100.0
            ELSE 0
        END AS decimal(8, 2)
    ) AS percentual_atingido,
    CASE
        WHEN b.valor_meta > 0 AND b.valor_realizado >= b.valor_meta THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS meta_batida,
    CASE
        WHEN b.valor_meta > 0 AND b.valor_realizado >= (b.valor_meta * 1.2) THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS meta_superada,
    DENSE_RANK() OVER (
        PARTITION BY b.data_id
        ORDER BY b.valor_realizado DESC, b.vendedor_id ASC
    ) AS ranking_periodo,
    CASE NTILE(4) OVER (
        PARTITION BY b.data_id
        ORDER BY b.valor_realizado DESC, b.vendedor_id ASC
    )
        WHEN 1 THEN 'Q1'
        WHEN 2 THEN 'Q2'
        WHEN 3 THEN 'Q3'
        ELSE 'Q4'
    END AS quartil_performance,
    b.itens_realizados,
    b.pedidos_realizados,
    CAST(GETDATE() AS datetime) AS data_atualizacao
FROM base AS b
WHERE b.valor_meta > 0 OR b.valor_realizado > 0;
GO

PRINT 'View fact.VW_DASH_METAS_R1 pronta para consumo.';
GO
