USE DW_ECOMMERCE;
GO

-- KPIs de referencia para homologacao do dashboard de vendas R1
-- Ajuste as datas conforme o periodo aplicado no filtro do dashboard.
DECLARE @data_inicio date = '2026-01-01';
DECLARE @data_fim date = '2026-01-31';

SELECT
    SUM(valor_total_liquido) AS receita_liquida,
    SUM(margem_bruta) AS margem_bruta,
    SUM(CASE WHEN quantidade_vendida > 0 THEN quantidade_devolvida ELSE 0 END) * 1.0
        / NULLIF(SUM(quantidade_vendida), 0) AS taxa_devolucao,
    SUM(valor_total_liquido) * 1.0
        / NULLIF(COUNT(DISTINCT numero_pedido), 0) AS ticket_medio,
    SUM(valor_total_descontos) * 1.0
        / NULLIF(SUM(valor_total_bruto), 0) AS desconto_medio
FROM fact.VW_DASH_VENDAS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim;
GO

-- Referencia adicional para tendencia mensal do mesmo periodo.
SELECT
    ano,
    mes,
    SUM(valor_total_liquido) AS receita_liquida,
    SUM(margem_bruta) AS margem_bruta
FROM fact.VW_DASH_VENDAS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim
GROUP BY ano, mes
ORDER BY ano, mes;
GO
