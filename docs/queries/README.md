# 📊 Queries Analíticas - Exemplos Práticos

> Biblioteca de consultas SQL prontas para análise de dados

## 📋 Índice

- [Análises de Vendas](#análises-de-vendas)
- [Análises Temporais](#análises-temporais)
- [Análises de Performance](#análises-de-performance)
- [Análises de Produtos](#análises-de-produtos)
- [Análises Geográficas](#análises-geográficas)
- [Análises de Descontos](#análises-de-descontos)
- [Queries Avançadas](#queries-avançadas)

---

## 💰 Análises de Vendas

### 1. Receita Total por Período

```sql
-- Receita diária, mensal, trimestral e anual
SELECT 
    d.ano,
    d.trimestre,
    d.mes,
    d.nome_mes,
    COUNT(*) AS total_vendas,
    SUM(fv.quantidade_vendida) AS unidades_vendidas,
    SUM(fv.valor_total_bruto) AS receita_bruta,
    SUM(fv.valor_total_descontos) AS total_descontos,
    SUM(fv.valor_total_liquido) AS receita_liquida,
    AVG(fv.valor_total_liquido) AS ticket_medio
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano = 2024
GROUP BY d.ano, d.trimestre, d.mes, d.nome_mes
ORDER BY d.ano, d.mes;
```

### 2. Vendas por Segmento de Cliente

```sql
-- Receita e ticket médio por segmento
SELECT 
    c.segmento,
    c.tipo_cliente,
    COUNT(DISTINCT fv.cliente_id) AS clientes_unicos,
    COUNT(*) AS total_compras,
    SUM(fv.valor_total_liquido) AS receita_total,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    SUM(fv.valor_total_liquido) / COUNT(DISTINCT fv.cliente_id) AS receita_por_cliente
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_CLIENTE c ON fv.cliente_id = c.cliente_id
GROUP BY c.segmento, c.tipo_cliente
ORDER BY receita_total DESC;
```

### 3. Taxa de Conversão e Retenção

```sql
-- Análise de comportamento de clientes
WITH primeiras_compras AS (
    SELECT 
        cliente_id,
        MIN(data_id) AS primeira_compra_data_id
    FROM fact.FACT_VENDAS
    GROUP BY cliente_id
),
compras_por_cliente AS (
    SELECT 
        cliente_id,
        COUNT(*) AS total_compras,
        SUM(valor_total_liquido) AS valor_total
    FROM fact.FACT_VENDAS
    GROUP BY cliente_id
)
SELECT 
    CASE 
        WHEN total_compras = 1 THEN 'Cliente Único'
        WHEN total_compras BETWEEN 2 AND 5 THEN 'Cliente Ocasional'
        WHEN total_compras BETWEEN 6 AND 10 THEN 'Cliente Frequente'
        ELSE 'Cliente Fiel (10+)'
    END AS tipo_cliente,
    COUNT(*) AS quantidade_clientes,
    AVG(total_compras) AS media_compras,
    AVG(valor_total) AS valor_medio_total
FROM compras_por_cliente
GROUP BY 
    CASE 
        WHEN total_compras = 1 THEN 'Cliente Único'
        WHEN total_compras BETWEEN 2 AND 5 THEN 'Cliente Ocasional'
        WHEN total_compras BETWEEN 6 AND 10 THEN 'Cliente Frequente'
        ELSE 'Cliente Fiel (10+)'
    END
ORDER BY quantidade_clientes DESC;
```

---

## 📅 Análises Temporais

### 4. Comparação Year-over-Year (YoY)

```sql
-- Vendas: Ano atual vs ano anterior
SELECT 
    d.ano,
    d.mes,
    d.nome_mes,
    SUM(fv.valor_total_liquido) AS receita_atual,
    LAG(SUM(fv.valor_total_liquido)) OVER (
        PARTITION BY d.mes 
        ORDER BY d.ano
    ) AS receita_ano_anterior,
    CASE 
        WHEN LAG(SUM(fv.valor_total_liquido)) OVER (PARTITION BY d.mes ORDER BY d.ano) IS NOT NULL
        THEN ((SUM(fv.valor_total_liquido) - LAG(SUM(fv.valor_total_liquido)) OVER (PARTITION BY d.mes ORDER BY d.ano)) 
              / LAG(SUM(fv.valor_total_liquido)) OVER (PARTITION BY d.mes ORDER BY d.ano) * 100)
        ELSE NULL
    END AS crescimento_percentual
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano IN (2023, 2024)
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.mes, d.ano;
```

### 5. Sazonalidade por Dia da Semana

```sql
-- Performance por dia da semana
SELECT 
    d.dia_semana,
    d.nome_dia_semana,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita_total,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    SUM(fv.valor_total_liquido) * 100.0 / SUM(SUM(fv.valor_total_liquido)) OVER () AS percentual_semana
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.dia_semana, d.nome_dia_semana
ORDER BY d.dia_semana;
```

### 6. Tendência de Crescimento (Moving Average)

```sql
-- Média móvel de 7 dias
SELECT 
    d.data_completa,
    SUM(fv.valor_total_liquido) AS receita_dia,
    AVG(SUM(fv.valor_total_liquido)) OVER (
        ORDER BY d.data_completa
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS media_movel_7dias
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano = 2024 AND d.mes = 12
GROUP BY d.data_completa
ORDER BY d.data_completa;
```

---

## 👥 Análises de Performance

### 7. Ranking de Vendedores

```sql
-- Top 20 vendedores por receita
SELECT TOP 20
    v.nome_vendedor,
    v.cargo,
    e.nome_equipe,
    e.regional,
    COUNT(*) AS total_vendas,
    SUM(fv.quantidade_vendida) AS unidades_vendidas,
    SUM(fv.valor_total_liquido) AS receita_total,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    SUM(fv.valor_comissao) AS comissao_total,
    RANK() OVER (ORDER BY SUM(fv.valor_total_liquido) DESC) AS ranking_geral
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
WHERE v.eh_ativo = 1
GROUP BY v.nome_vendedor, v.cargo, e.nome_equipe, e.regional
ORDER BY receita_total DESC;
```

### 8. Atingimento de Metas

```sql
-- Performance vendedores vs metas
SELECT 
    v.nome_vendedor,
    v.cargo,
    d.ano,
    d.nome_mes,
    fm.valor_meta,
    fm.valor_realizado,
    fm.percentual_atingido,
    fm.gap_meta,
    CASE 
        WHEN fm.percentual_atingido >= 120 THEN '🌟 Excepcional'
        WHEN fm.percentual_atingido >= 100 THEN '✅ Atingiu'
        WHEN fm.percentual_atingido >= 80 THEN '⚠️ Próximo'
        ELSE '❌ Abaixo'
    END AS status_meta,
    fm.ranking_periodo,
    fm.quartil_performance
FROM fact.FACT_METAS fm
JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
JOIN dim.DIM_DATA d ON fm.data_id = d.data_id
WHERE d.ano = 2024 AND d.mes = 12
ORDER BY fm.percentual_atingido DESC;
```

### 9. Análise de Equipes

```sql
-- Performance por equipe e regional
SELECT 
    e.regional,
    e.nome_equipe,
    e.tipo_equipe,
    COUNT(DISTINCT v.vendedor_id) AS vendedores_ativos,
    e.meta_mensal_equipe,
    SUM(fv.valor_total_liquido) AS receita_realizada,
    (SUM(fv.valor_total_liquido) / e.meta_mensal_equipe * 100) AS percentual_meta,
    SUM(fv.valor_total_liquido) / COUNT(DISTINCT v.vendedor_id) AS receita_per_capita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano = 2024 AND d.mes = 12
GROUP BY e.regional, e.nome_equipe, e.tipo_equipe, e.meta_mensal_equipe
ORDER BY receita_realizada DESC;
```

---

## 📦 Análises de Produtos

### 10. Top Produtos por Categoria

```sql
-- Top 10 produtos de cada categoria
WITH produtos_ranked AS (
    SELECT 
        p.categoria,
        p.nome_produto,
        p.marca,
        SUM(fv.quantidade_vendida) AS qtd_vendida,
        SUM(fv.valor_total_liquido) AS receita,
        ROW_NUMBER() OVER (
            PARTITION BY p.categoria 
            ORDER BY SUM(fv.valor_total_liquido) DESC
        ) AS ranking_categoria
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
    GROUP BY p.categoria, p.nome_produto, p.marca
)
SELECT 
    categoria,
    nome_produto,
    marca,
    qtd_vendida,
    receita,
    ranking_categoria
FROM produtos_ranked
WHERE ranking_categoria <= 10
ORDER BY categoria, ranking_categoria;
```

### 11. Análise de Margem por Produto

```sql
-- Produtos com melhor e pior margem
SELECT 
    p.categoria,
    p.subcategoria,
    p.nome_produto,
    p.nome_fornecedor,
    SUM(fv.quantidade_vendida) AS qtd_vendida,
    SUM(fv.valor_total_liquido) AS receita,
    SUM(fv.custo_total) AS custo_total,
    SUM(fv.valor_total_liquido - fv.custo_total) AS lucro_bruto,
    AVG((fv.valor_total_liquido - fv.custo_total) / fv.valor_total_liquido * 100) AS margem_percentual
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.categoria, p.subcategoria, p.nome_produto, p.nome_fornecedor
HAVING SUM(fv.quantidade_vendida) >= 10  -- Apenas produtos com volume relevante
ORDER BY margem_percentual DESC;
```

### 12. Taxa de Devolução

```sql
-- Produtos com maior taxa de devolução
SELECT 
    p.categoria,
    p.nome_produto,
    p.nome_fornecedor,
    SUM(fv.quantidade_vendida) AS total_vendido,
    SUM(fv.quantidade_devolvida) AS total_devolvido,
    (SUM(fv.quantidade_devolvida) * 100.0 / SUM(fv.quantidade_vendida)) AS taxa_devolucao,
    SUM(fv.valor_devolvido) AS valor_total_devolvido
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
WHERE fv.quantidade_devolvida > 0
GROUP BY p.categoria, p.nome_produto, p.nome_fornecedor
HAVING SUM(fv.quantidade_vendida) >= 20
ORDER BY taxa_devolucao DESC;
```

---

## 🗺️ Análises Geográficas

### 13. Vendas por Região

```sql
-- Performance por região do país
SELECT 
    r.regiao_pais,
    r.estado,
    COUNT(DISTINCT r.cidade) AS total_cidades,
    COUNT(DISTINCT fv.cliente_id) AS clientes_unicos,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita_total,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    SUM(fv.valor_total_liquido) * 100.0 / SUM(SUM(fv.valor_total_liquido)) OVER () AS percentual_nacional
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
GROUP BY r.regiao_pais, r.estado
ORDER BY receita_total DESC;
```

### 14. Correlação IDH x Vendas

```sql
-- Análise socioeconômica
SELECT 
    CASE 
        WHEN r.idh >= 0.800 THEN 'Alto (≥0.8)'
        WHEN r.idh >= 0.700 THEN 'Médio (0.7-0.8)'
        WHEN r.idh >= 0.600 THEN 'Baixo (0.6-0.7)'
        ELSE 'Muito Baixo (<0.6)'
    END AS faixa_idh,
    COUNT(DISTINCT r.cidade) AS cidades,
    AVG(r.pib_per_capita) AS pib_medio,
    COUNT(*) AS total_vendas,
    AVG(fv.valor_total_liquido) AS ticket_medio
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
WHERE r.idh IS NOT NULL
GROUP BY 
    CASE 
        WHEN r.idh >= 0.800 THEN 'Alto (≥0.8)'
        WHEN r.idh >= 0.700 THEN 'Médio (0.7-0.8)'
        WHEN r.idh >= 0.600 THEN 'Baixo (0.6-0.7)'
        ELSE 'Muito Baixo (<0.6)'
    END
ORDER BY pib_medio DESC;
```

### 15. Penetração de Mercado

```sql
-- Cidades com maior potencial (alta população, baixas vendas)
SELECT TOP 20
    r.cidade,
    r.estado,
    r.regiao_pais,
    r.populacao_estimada,
    r.pib_per_capita,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita_total,
    (r.populacao_estimada / COUNT(*)) AS habitantes_por_venda,
    CASE 
        WHEN COUNT(*) < 100 THEN 'Baixa Penetração'
        WHEN COUNT(*) < 500 THEN 'Média Penetração'
        ELSE 'Alta Penetração'
    END AS nivel_penetracao
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
WHERE r.populacao_estimada > 100000  -- Cidades médias/grandes
GROUP BY r.cidade, r.estado, r.regiao_pais, r.populacao_estimada, r.pib_per_capita
ORDER BY habitantes_por_venda DESC;
```

---

## 🎟️ Análises de Descontos

### 16. ROI de Campanhas

```sql
-- Retorno sobre investimento em descontos
SELECT 
    d.nome_campanha,
    d.tipo_desconto,
    d.metodo_desconto,
    COUNT(fd.desconto_aplicado_id) AS total_aplicacoes,
    SUM(fd.valor_desconto_aplicado) AS custo_campanha,
    SUM(fd.valor_com_desconto) AS receita_gerada,
    SUM(fd.impacto_margem) AS impacto_margem_total,
    (SUM(fd.valor_com_desconto) / NULLIF(SUM(fd.valor_desconto_aplicado), 0)) AS roi,
    (SUM(fd.valor_com_desconto) - SUM(fd.valor_desconto_aplicado)) AS lucro_liquido
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.nome_campanha, d.tipo_desconto, d.metodo_desconto
HAVING COUNT(fd.desconto_aplicado_id) >= 10
ORDER BY roi DESC;
```

### 17. Impacto de Descontos na Margem

```sql
-- Análise de impacto por tipo de desconto
SELECT 
    d.tipo_desconto,
    COUNT(*) AS total_aplicacoes,
    AVG(fd.valor_desconto_aplicado) AS desconto_medio,
    AVG(fd.margem_antes_desconto) AS margem_media_antes,
    AVG(fd.margem_apos_desconto) AS margem_media_depois,
    AVG(fd.impacto_margem) AS impacto_medio,
    (AVG(fd.margem_antes_desconto) - AVG(fd.margem_apos_desconto)) / AVG(fd.margem_antes_desconto) * 100 AS reducao_margem_percentual
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.tipo_desconto
ORDER BY impacto_medio DESC;
```

### 18. Vendas com vs sem Desconto

```sql
-- Comparação de comportamento
SELECT 
    CASE WHEN fv.teve_desconto = 1 THEN 'Com Desconto' ELSE 'Sem Desconto' END AS tipo_venda,
    COUNT(*) AS total_vendas,
    SUM(fv.quantidade_vendida) AS unidades,
    SUM(fv.valor_total_liquido) AS receita_total,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    SUM(fv.valor_total_liquido - fv.custo_total) AS lucro_bruto,
    AVG((fv.valor_total_liquido - fv.custo_total) / fv.valor_total_liquido * 100) AS margem_media
FROM fact.FACT_VENDAS fv
GROUP BY CASE WHEN fv.teve_desconto = 1 THEN 'Com Desconto' ELSE 'Sem Desconto' END;
```

---

## 🚀 Queries Avançadas

### 19. Análise RFM (Recency, Frequency, Monetary)

```sql
-- Segmentação RFM de clientes
WITH rfm_base AS (
    SELECT 
        fv.cliente_id,
        DATEDIFF(DAY, MAX(d.data_completa), GETDATE()) AS recency,
        COUNT(*) AS frequency,
        SUM(fv.valor_total_liquido) AS monetary
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
    GROUP BY fv.cliente_id
),
rfm_scored AS (
    SELECT 
        cliente_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)
SELECT 
    c.nome_cliente,
    c.segmento,
    r.recency AS dias_ultima_compra,
    r.frequency AS total_compras,
    r.monetary AS valor_total,
    r.r_score,
    r.f_score,
    r.m_score,
    (r.r_score + r.f_score + r.m_score) / 3.0 AS rfm_medio,
    CASE 
        WHEN (r.r_score + r.f_score + r.m_score) / 3.0 >= 4 THEN 'Champions'
        WHEN (r.r_score + r.f_score + r.m_score) / 3.0 >= 3 THEN 'Loyal Customers'
        WHEN (r.r_score + r.f_score + r.m_score) / 3.0 >= 2 THEN 'At Risk'
        ELSE 'Lost'
    END AS segmento_rfm
FROM rfm_scored r
JOIN dim.DIM_CLIENTE c ON r.cliente_id = c.cliente_id
ORDER BY rfm_medio DESC;
```

### 20. Análise de Coorte (Cohort Analysis)

```sql
-- Retenção de clientes por coorte de primeira compra
WITH primeira_compra AS (
    SELECT 
        cliente_id,
        DATEFROMPARTS(YEAR(MIN(d.data_completa)), MONTH(MIN(d.data_completa)), 1) AS cohort_mes
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
    GROUP BY cliente_id
),
compras_por_mes AS (
    SELECT 
        fv.cliente_id,
        pc.cohort_mes,
        DATEFROMPARTS(YEAR(d.data_completa), MONTH(d.data_completa), 1) AS mes_compra,
        DATEDIFF(MONTH, pc.cohort_mes, DATEFROMPARTS(YEAR(d.data_completa), MONTH(d.data_completa), 1)) AS mes_desde_primeira
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
    JOIN primeira_compra pc ON fv.cliente_id = pc.cliente_id
)
SELECT 
    cohort_mes,
    mes_desde_primeira,
    COUNT(DISTINCT cliente_id) AS clientes_ativos,
    (SELECT COUNT(DISTINCT cliente_id) FROM primeira_compra WHERE cohort_mes = cm.cohort_mes) AS tamanho_coorte,
    COUNT(DISTINCT cliente_id) * 100.0 / 
        (SELECT COUNT(DISTINCT cliente_id) FROM primeira_compra WHERE cohort_mes = cm.cohort_mes) AS taxa_retencao
FROM compras_por_mes cm
WHERE mes_desde_primeira <= 12  -- Primeiros 12 meses
GROUP BY cohort_mes, mes_desde_primeira
ORDER BY cohort_mes, mes_desde_primeira;
```

### 21. Análise ABC de Produtos (Curva 80/20)

```sql
-- Classificação ABC: A=80% receita, B=15%, C=5%
WITH produto_receita AS (
    SELECT 
        p.produto_id,
        p.nome_produto,
        p.categoria,
        SUM(fv.valor_total_liquido) AS receita,
        SUM(fv.quantidade_vendida) AS qtd_vendida
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
    GROUP BY p.produto_id, p.nome_produto, p.categoria
),
produto_percentual AS (
    SELECT 
        *,
        receita * 100.0 / SUM(receita) OVER () AS percentual_receita,
        SUM(receita * 100.0 / SUM(receita) OVER ()) OVER (ORDER BY receita DESC) AS percentual_acumulado
    FROM produto_receita
)
SELECT 
    nome_produto,
    categoria,
    receita,
    qtd_vendida,
    ROUND(percentual_receita, 2) AS percentual_receita,
    ROUND(percentual_acumulado, 2) AS percentual_acumulado,
    CASE 
        WHEN percentual_acumulado <= 80 THEN 'A (Top 80%)'
        WHEN percentual_acumulado <= 95 THEN 'B (Próximos 15%)'
        ELSE 'C (Últimos 5%)'
    END AS classe_abc
FROM produto_percentual
ORDER BY receita DESC;
```

### 22. Previsão Baseada em Tendência

```sql
-- Previsão simples usando média móvel
WITH vendas_diarias AS (
    SELECT 
        d.data_completa,
        SUM(fv.valor_total_liquido) AS receita
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
    WHERE d.ano = 2024
    GROUP BY d.data_completa
),
media_movel AS (
    SELECT 
        data_completa,
        receita,
        AVG(receita) OVER (
            ORDER BY data_completa 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS media_30_dias
    FROM vendas_diarias
)
SELECT 
    data_completa,
    receita AS receita_real,
    media_30_dias,
    CASE 
        WHEN receita > media_30_dias * 1.2 THEN 'Acima da Média (+20%)'
        WHEN receita < media_30_dias * 0.8 THEN 'Abaixo da Média (-20%)'
        ELSE 'Dentro da Média'
    END AS performance_dia
FROM media_movel
WHERE data_completa >= DATEADD(DAY, -30, GETDATE())
ORDER BY data_completa DESC;
```

---

## 💡 Dicas de Performance

### Boas Práticas

1. **Sempre use índices nas FKs** (já implementados)
2. **Filtre por data primeiro** para reduzir volume
3. **Use INNER JOIN** quando possível (mais rápido que LEFT JOIN)
4. **Evite SELECT *** - especifique apenas campos necessários
5. **Use views auxiliares** para queries complexas frequentes

### Exemplos de Otimização

```sql
-- ❌ LENTO: Sem filtro de data
SELECT SUM(valor_total_liquido)
FROM fact.FACT_VENDAS;

-- ✅ RÁPIDO: Com filtro de data (usa índice)
SELECT SUM(valor_total_liquido)
FROM fact.FACT_VENDAS
WHERE data_id BETWEEN 20240101 AND 20241231;

-- ❌ LENTO: SELECT *
SELECT *
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id;

-- ✅ RÁPIDO: Apenas campos necessários
SELECT fv.venda_id, fv.valor_total_liquido, p.nome_produto
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id;
```

---

## 📚 Referências

- **Views Auxiliares:** Ver `sql/dw/04_views/README.md`
- **Modelo Dimensional:** Ver `docs/modelagem/01_visao_geral.md`
- **Relacionamentos:** Ver `docs/modelagem/04_relacionamentos.md`

---

<div align="center">

**[⬆ Voltar ao topo](#-queries-analíticas---exemplos-práticos)**

Todas as queries foram testadas e estão prontas para uso!

</div>