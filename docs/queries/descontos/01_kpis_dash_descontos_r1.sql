USE DW_ECOMMERCE;
GO

-- KPIs de referencia para homologacao do dashboard de descontos/ROI R1
-- Ajuste as datas conforme o periodo aplicado no filtro do dashboard.
DECLARE @data_inicio date = '2026-01-01';
DECLARE @data_fim date = '2026-01-31';

SELECT
    COUNT(*) AS total_aplicacoes_desconto,
    SUM(valor_desconto_aplicado) AS desconto_total_concedido,
    SUM(valor_com_desconto) AS receita_com_desconto,
    AVG(percentual_desconto_efetivo) AS percentual_desconto_medio,
    SUM(impacto_margem) AS impacto_margem_total,
    SUM(impacto_margem) * 1.0 / NULLIF(SUM(valor_com_desconto), 0) AS impacto_margem_pct_receita,
    AVG(CASE WHEN desconto_aprovado = 1 THEN 1.0 ELSE 0.0 END) AS taxa_aprovacao,
    AVG(roi_desconto) AS roi_medio,
    (
        SUM(valor_com_desconto) - SUM(valor_desconto_aplicado)
    ) * 1.0 / NULLIF(SUM(valor_desconto_aplicado), 0) AS roi_ponderado
FROM fact.VW_DASH_DESCONTOS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim;
GO

-- Referencia adicional para analise temporal.
SELECT
    ano,
    mes,
    COUNT(*) AS total_aplicacoes,
    SUM(valor_desconto_aplicado) AS desconto_total_concedido,
    SUM(valor_com_desconto) AS receita_com_desconto,
    AVG(roi_desconto) AS roi_medio
FROM fact.VW_DASH_DESCONTOS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim
GROUP BY ano, mes
ORDER BY ano, mes;
GO

-- Referencia adicional para ranking de campanhas/codigos.
SELECT TOP 20
    codigo_desconto,
    nome_campanha,
    tipo_desconto,
    metodo_desconto,
    COUNT(*) AS total_aplicacoes,
    SUM(valor_desconto_aplicado) AS desconto_total_concedido,
    SUM(valor_com_desconto) AS receita_com_desconto,
    AVG(roi_desconto) AS roi_medio
FROM fact.VW_DASH_DESCONTOS_R1
WHERE CAST(data_completa AS date) BETWEEN @data_inicio AND @data_fim
GROUP BY codigo_desconto, nome_campanha, tipo_desconto, metodo_desconto
ORDER BY desconto_total_concedido DESC, receita_com_desconto DESC;
GO
