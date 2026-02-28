USE DW_ECOMMERCE;
GO

-- KPIs de referencia para homologacao do dashboard de metas R1
-- Ajuste as datas conforme o periodo aplicado no filtro do dashboard.
DECLARE @data_inicio date = '2026-01-01';
DECLARE @data_fim date = '2026-01-31';

SELECT
    SUM(valor_meta) AS meta_total,
    SUM(valor_realizado) AS realizado_total,
    SUM(valor_realizado) * 1.0 / NULLIF(SUM(valor_meta), 0) AS percentual_atingimento_geral,
    SUM(gap_meta) AS gap_total,
    AVG(CASE WHEN meta_batida = 1 THEN 1.0 ELSE 0.0 END) AS taxa_meta_batida
FROM fact.VW_DASH_METAS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim;
GO

-- Referencia adicional para tendencia mensal e ranking por equipe.
SELECT
    ano,
    mes,
    SUM(valor_meta) AS meta_total,
    SUM(valor_realizado) AS realizado_total,
    SUM(valor_realizado) * 1.0 / NULLIF(SUM(valor_meta), 0) AS percentual_atingimento_geral
FROM fact.VW_DASH_METAS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim
GROUP BY ano, mes
ORDER BY ano, mes;
GO

SELECT
    nome_equipe,
    SUM(valor_meta) AS meta_total,
    SUM(valor_realizado) AS realizado_total,
    SUM(valor_realizado) * 1.0 / NULLIF(SUM(valor_meta), 0) AS percentual_atingimento_equipe,
    SUM(CASE WHEN meta_batida = 1 THEN 1 ELSE 0 END) AS vendedores_com_meta_batida
FROM fact.VW_DASH_METAS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim
GROUP BY nome_equipe
ORDER BY percentual_atingimento_equipe DESC, realizado_total DESC;
GO
