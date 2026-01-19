# 📊 Tabelas Fato - Documentação Detalhada

> Especificação completa das 3 tabelas fato do modelo

## 📋 Índice

- [Conceitos de Facts](#conceitos-de-facts)
- [FACT_VENDAS](#fact_vendas---transacional)
- [FACT_METAS](#fact_metas---snapshot-periódico)
- [FACT_DESCONTOS](#fact_descontos---eventos)
- [Comparação entre Facts](#comparação-entre-facts)
- [Padrões de Consulta](#padrões-de-consulta)

---

## 🎯 Conceitos de Facts

### O que é uma Tabela Fato?

Uma **fact table** é a tabela central do modelo dimensional que armazena:

1. **Métricas numéricas** (valores quantitativos)
2. **Foreign Keys** para dimensões (contexto)
3. **Degenerate Dimensions** (atributos operacionais)

```
┌─────────────────────────────────────────────────────────────────┐
│ ANATOMIA DE UMA FACT TABLE                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 🔑 CHAVES                                                       │
│    ├─ PK: venda_id (surrogate key)                             │
│    ├─ FK: data_id → DIM_DATA                                    │
│    ├─ FK: cliente_id → DIM_CLIENTE                              │
│    ├─ FK: produto_id → DIM_PRODUTO                              │
│    └─ FK: regiao_id → DIM_REGIAO                                │
│                                                                 │
│ 📈 MÉTRICAS (Fatos numéricos)                                   │
│    ├─ quantidade_vendida (aditiva)                              │
│    ├─ valor_total_liquido (aditiva)                             │
│    ├─ percentual_desconto (semi-aditiva)                        │
│    └─ margem_percentual (não-aditiva)                           │
│                                                                 │
│ 🏷️ DEGENERATE DIMENSIONS                                        │
│    └─ numero_pedido (atributo operacional)                      │
│                                                                 │
│ 🚩 FLAGS                                                        │
│    └─ teve_desconto (indicador booleano)                        │
└─────────────────────────────────────────────────────────────────┘
```

### Tipos de Métricas

| Tipo | Descrição | Exemplo | Pode Somar? |
|------|-----------|---------|-------------|
| **Aditiva** | Pode somar em todas dimensões | quantidade_vendida, receita | ✅ Sempre |
| **Semi-Aditiva** | Pode somar em algumas dimensões | saldo_conta, estoque | ⚠️ Não no tempo |
| **Não-Aditiva** | Nunca deve somar | percentual, taxa, índice | ❌ Nunca |

```sql
-- ✅ ADITIVA: Pode somar tudo
SELECT SUM(quantidade_vendida) FROM FACT_VENDAS;
SELECT SUM(valor_total_liquido) FROM FACT_VENDAS;

-- ⚠️ SEMI-ADITIVA: Não somar no tempo
SELECT estoque_atual FROM FACT_ESTOQUE WHERE data = '2024-12-31';
-- ❌ ERRADO: SELECT SUM(estoque_atual) -- soma estoques de dias diferentes!

-- ❌ NÃO-ADITIVA: Calcular, não somar
SELECT AVG(margem_percentual) FROM FACT_VENDAS;
-- ❌ ERRADO: SELECT SUM(margem_percentual) -- não faz sentido!
```

---

## 🛒 FACT_VENDAS - Transacional

### 🎯 Propósito

Tabela fato **principal** do DW. Captura cada item vendido no e-commerce.

### 📐 Granularidade

```
1 linha = 1 ITEM vendido em 1 PEDIDO

Exemplo: Pedido #12345
├─ Item 1: Notebook Dell (2 unid)     → 1 LINHA
├─ Item 2: Mouse Logitech (1 unid)    → 1 LINHA
└─ Item 3: Teclado Mecânico (1 unid)  → 1 LINHA
                                        ─────────
                                        3 linhas na fact
```

### 📊 Estrutura Completa

```sql
CREATE TABLE fact.FACT_VENDAS (
    -- ═══════════════════════════════════════════
    -- CHAVE PRIMÁRIA
    -- ═══════════════════════════════════════════
    venda_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    
    -- ═══════════════════════════════════════════
    -- FOREIGN KEYS (Dimensões)
    -- ═══════════════════════════════════════════
    data_id INT NOT NULL,              -- QUANDO vendeu?
    cliente_id INT NOT NULL,           -- QUEM comprou?
    produto_id INT NOT NULL,           -- O QUE comprou?
    regiao_id INT NOT NULL,            -- ONDE entregou?
    vendedor_id INT NULL,              -- QUEM vendeu? (NULL = e-commerce direto)
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS DE QUANTIDADE (Aditivas)
    -- ═══════════════════════════════════════════
    quantidade_vendida INT NOT NULL,
    quantidade_devolvida INT DEFAULT 0,
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS FINANCEIRAS (Aditivas)
    -- ═══════════════════════════════════════════
    preco_unitario_tabela DECIMAL(10,2) NOT NULL,
    valor_total_bruto DECIMAL(15,2) NOT NULL,
    valor_total_descontos DECIMAL(15,2) DEFAULT 0,
    valor_total_liquido DECIMAL(15,2) NOT NULL,
    custo_total DECIMAL(15,2) NOT NULL,
    valor_devolvido DECIMAL(15,2) DEFAULT 0,
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS DE COMISSÃO
    -- ═══════════════════════════════════════════
    percentual_comissao DECIMAL(5,2) NULL,
    valor_comissao DECIMAL(15,2) NULL,
    
    -- ═══════════════════════════════════════════
    -- DEGENERATE DIMENSION
    -- ═══════════════════════════════════════════
    numero_pedido VARCHAR(20) NOT NULL,
    
    -- ═══════════════════════════════════════════
    -- FLAGS
    -- ═══════════════════════════════════════════
    teve_desconto BIT DEFAULT 0,
    
    -- ═══════════════════════════════════════════
    -- CONSTRAINTS
    -- ═══════════════════════════════════════════
    CONSTRAINT FK_FACT_VENDAS_data FOREIGN KEY (data_id) REFERENCES dim.DIM_DATA(data_id),
    CONSTRAINT FK_FACT_VENDAS_cliente FOREIGN KEY (cliente_id) REFERENCES dim.DIM_CLIENTE(cliente_id),
    CONSTRAINT FK_FACT_VENDAS_produto FOREIGN KEY (produto_id) REFERENCES dim.DIM_PRODUTO(produto_id),
    CONSTRAINT FK_FACT_VENDAS_regiao FOREIGN KEY (regiao_id) REFERENCES dim.DIM_REGIAO(regiao_id),
    CONSTRAINT FK_FACT_VENDAS_vendedor FOREIGN KEY (vendedor_id) REFERENCES dim.DIM_VENDEDOR(vendedor_id),
    
    CONSTRAINT CK_FACT_VENDAS_quantidade_positiva CHECK (quantidade_vendida > 0),
    CONSTRAINT CK_FACT_VENDAS_valor_liquido_coerente 
        CHECK (valor_total_liquido = valor_total_bruto - valor_total_descontos)
);
```

### 📈 Métricas Principais

| Métrica | Tipo | Fórmula | Uso |
|---------|------|---------|-----|
| `quantidade_vendida` | Aditiva | Informada | Volume de vendas |
| `valor_total_bruto` | Aditiva | qtd × preço_unit | Receita sem desconto |
| `valor_total_descontos` | Aditiva | Soma descontos | Impacto promoções |
| `valor_total_liquido` | Aditiva | bruto - descontos | **RECEITA REAL** |
| `custo_total` | Aditiva | qtd × custo_unit | Custo mercadoria |
| `lucro_bruto` | **Calculada** | liquido - custo | Margem bruta |
| `margem_percentual` | **Calculada** | lucro/liquido×100 | % de lucro |

### 🔍 Análises Suportadas

```sql
-- 1. Receita por período
SELECT 
    d.ano,
    d.mes,
    SUM(fv.valor_total_liquido) AS receita,
    SUM(fv.quantidade_vendida) AS unidades
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.ano, d.mes
ORDER BY d.ano, d.mes;

-- 2. Top produtos por categoria
SELECT 
    p.categoria,
    p.nome_produto,
    SUM(fv.quantidade_vendida) AS qtd_vendida,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.categoria, p.nome_produto
ORDER BY receita DESC;

-- 3. Análise de margem por região
SELECT 
    r.regiao_pais,
    r.estado,
    SUM(fv.valor_total_liquido - fv.custo_total) AS lucro_bruto,
    AVG((fv.valor_total_liquido - fv.custo_total) / fv.valor_total_liquido * 100) AS margem_media
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
GROUP BY r.regiao_pais, r.estado;

-- 4. Taxa de devolução
SELECT 
    p.categoria,
    p.nome_fornecedor,
    SUM(fv.quantidade_devolvida) AS total_devolvido,
    SUM(fv.quantidade_vendida) AS total_vendido,
    (SUM(fv.quantidade_devolvida) * 100.0 / SUM(fv.quantidade_vendida)) AS taxa_devolucao
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.categoria, p.nome_fornecedor
HAVING SUM(fv.quantidade_devolvida) > 0;

-- 5. Performance de vendedores
SELECT 
    v.nome_vendedor,
    v.nome_equipe,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita,
    SUM(fv.valor_comissao) AS comissao
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
WHERE fv.vendedor_id IS NOT NULL
GROUP BY v.nome_vendedor, v.nome_equipe
ORDER BY receita DESC;
```

### 📝 Observações Importantes

- **Por que BIGINT na PK?** Facts crescem muito! INT suporta ~2 bilhões, BIGINT ~9 quintilhões
- **Por que `vendedor_id` aceita NULL?** Vendas diretas (e-commerce sem vendedor)
- **Por que armazenar `valor_total_liquido` se é calculável?** Performance e consistência
- **View auxiliar:** `VW_VENDAS_COMPLETA` faz todos os JOINs

---

## 🎯 FACT_METAS - Snapshot Periódico

### 🎯 Propósito

Captura **metas e performance** de vendedores em intervalos regulares (mensal).

### 📐 Granularidade

```
1 linha = META de 1 VENDEDOR em 1 PERÍODO

Exemplo: Vendedor João em 2024
├─ Janeiro/2024    → 1 LINHA (meta: 50k, realizado: 52k)
├─ Fevereiro/2024  → 1 LINHA (meta: 50k, realizado: 48k)
└─ Março/2024      → 1 LINHA (meta: 55k, realizado: 60k)
```

### 📊 Estrutura Completa

```sql
CREATE TABLE fact.FACT_METAS (
    -- ═══════════════════════════════════════════
    -- CHAVE PRIMÁRIA
    -- ═══════════════════════════════════════════
    meta_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    
    -- ═══════════════════════════════════════════
    -- FOREIGN KEYS
    -- ═══════════════════════════════════════════
    vendedor_id INT NOT NULL,
    data_id INT NOT NULL,              -- 1º dia do mês/trimestre
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS DE META (Objetivo)
    -- ═══════════════════════════════════════════
    valor_meta DECIMAL(15,2) NOT NULL,
    quantidade_meta INT NULL,
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS REALIZADAS (O que aconteceu)
    -- ═══════════════════════════════════════════
    valor_realizado DECIMAL(15,2) DEFAULT 0,
    quantidade_realizada INT DEFAULT 0,
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS CALCULADAS (Performance)
    -- ═══════════════════════════════════════════
    percentual_atingido DECIMAL(5,2) DEFAULT 0,  -- (realizado/meta)*100
    gap_meta DECIMAL(15,2) DEFAULT 0,             -- realizado - meta
    ticket_medio_realizado DECIMAL(10,2) NULL,
    
    -- ═══════════════════════════════════════════
    -- CLASSIFICAÇÃO
    -- ═══════════════════════════════════════════
    ranking_periodo INT NULL,
    quartil_performance VARCHAR(10) NULL,         -- Q1, Q2, Q3, Q4
    
    -- ═══════════════════════════════════════════
    -- FLAGS
    -- ═══════════════════════════════════════════
    meta_batida BIT DEFAULT 0,
    meta_superada BIT DEFAULT 0,
    eh_periodo_fechado BIT DEFAULT 0,
    
    -- ═══════════════════════════════════════════
    -- TIPO
    -- ═══════════════════════════════════════════
    tipo_periodo VARCHAR(20) DEFAULT 'Mensal',    -- Mensal, Trimestral, Anual
    
    -- ═══════════════════════════════════════════
    -- CONSTRAINTS
    -- ═══════════════════════════════════════════
    CONSTRAINT UK_FACT_METAS_vendedor_periodo UNIQUE (vendedor_id, data_id, tipo_periodo),
    CONSTRAINT FK_FACT_METAS_vendedor FOREIGN KEY (vendedor_id) REFERENCES dim.DIM_VENDEDOR(vendedor_id),
    CONSTRAINT FK_FACT_METAS_data FOREIGN KEY (data_id) REFERENCES dim.DIM_DATA(data_id),
    
    CONSTRAINT CK_FACT_METAS_valor_meta_positivo CHECK (valor_meta > 0),
    CONSTRAINT CK_FACT_METAS_meta_batida_coerente 
        CHECK ((meta_batida = 0 AND percentual_atingido < 100) OR 
               (meta_batida = 1 AND percentual_atingido >= 100))
);
```

### 📈 Métricas Principais

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `valor_meta` | Aditiva | Meta de receita (R$) |
| `valor_realizado` | Aditiva | Receita alcançada (R$) |
| `percentual_atingido` | Não-Aditiva | (realizado/meta)×100 |
| `gap_meta` | Aditiva | Diferença: realizado - meta |
| `ranking_periodo` | Não-Aditiva | Posição no mês (1=melhor) |

### 🔍 Análises Suportadas

```sql
-- 1. Atingimento de metas por vendedor
SELECT 
    v.nome_vendedor,
    COUNT(*) AS total_periodos,
    SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) AS periodos_bateu_meta,
    AVG(fm.percentual_atingido) AS perc_medio
FROM fact.FACT_METAS fm
JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
GROUP BY v.nome_vendedor
ORDER BY perc_medio DESC;

-- 2. Evolução de performance ao longo do tempo
SELECT 
    d.ano,
    d.mes,
    d.nome_mes,
    AVG(fm.percentual_atingido) AS media_atingimento,
    COUNT(CASE WHEN fm.meta_batida = 1 THEN 1 END) AS qtd_bateram_meta
FROM fact.FACT_METAS fm
JOIN dim.DIM_DATA d ON fm.data_id = d.data_id
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.ano, d.mes;

-- 3. Análise por quartil
SELECT 
    quartil_performance,
    COUNT(*) AS total_vendedores,
    AVG(percentual_atingido) AS perc_medio,
    MIN(percentual_atingido) AS perc_min,
    MAX(percentual_atingido) AS perc_max
FROM fact.FACT_METAS
WHERE quartil_performance IS NOT NULL
GROUP BY quartil_performance;

-- 4. Previsão baseada em tendência
SELECT 
    vendedor_id,
    AVG(percentual_atingido) AS media_historica,
    CASE 
        WHEN AVG(percentual_atingido) >= 100 THEN 'Tende a bater meta'
        WHEN AVG(percentual_atingido) >= 80 THEN 'Risco médio'
        ELSE 'Alto risco de não bater'
    END AS previsao
FROM fact.FACT_METAS
GROUP BY vendedor_id;
```

### 📝 Características Especiais

- **Tipo:** Periodic Snapshot (congela estado em intervalos)
- **Atualização:** Mensal (após fechamento)
- **Tamanho:** Previsível (N vendedores × M períodos)
- **View auxiliar:** `VW_METAS_COMPLETA`

---

## 🎟️ FACT_DESCONTOS - Eventos

### 🎯 Propósito

Registra cada **desconto aplicado** em vendas. Permite análise de ROI de campanhas.

### 📐 Granularidade

```
1 linha = 1 DESCONTO aplicado em 1 VENDA

Exemplo: Venda #123
├─ Cupom BLACKFRIDAY (-10%)     → 1 LINHA
├─ Desconto Volume (-5%)         → 1 LINHA
└─ Frete Grátis                  → 1 LINHA
                                   ─────────
                                   3 linhas (múltiplos descontos)
```

### 📊 Estrutura Completa

```sql
CREATE TABLE fact.FACT_DESCONTOS (
    -- ═══════════════════════════════════════════
    -- CHAVE PRIMÁRIA
    -- ═══════════════════════════════════════════
    desconto_aplicado_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    
    -- ═══════════════════════════════════════════
    -- FOREIGN KEYS
    -- ═══════════════════════════════════════════
    desconto_id INT NOT NULL,
    venda_id BIGINT NOT NULL,
    data_aplicacao_id INT NOT NULL,
    cliente_id INT NOT NULL,
    produto_id INT NOT NULL,
    
    -- ═══════════════════════════════════════════
    -- CONTEXTO DO DESCONTO
    -- ═══════════════════════════════════════════
    nivel_aplicacao VARCHAR(20) NOT NULL,         -- Produto, Pedido, Frete
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS FINANCEIRAS
    -- ═══════════════════════════════════════════
    valor_desconto_aplicado DECIMAL(10,2) NOT NULL,
    valor_sem_desconto DECIMAL(15,2) NOT NULL,
    valor_com_desconto DECIMAL(15,2) NOT NULL,
    
    -- ═══════════════════════════════════════════
    -- MÉTRICAS DE IMPACTO
    -- ═══════════════════════════════════════════
    margem_antes_desconto DECIMAL(15,2) NULL,
    margem_apos_desconto DECIMAL(15,2) NULL,
    impacto_margem DECIMAL(15,2) NULL,            -- margem_antes - margem_apos
    
    -- ═══════════════════════════════════════════
    -- DEGENERATE DIMENSION
    -- ═══════════════════════════════════════════
    numero_pedido VARCHAR(20) NOT NULL,
    
    -- ═══════════════════════════════════════════
    -- FLAGS
    -- ═══════════════════════════════════════════
    desconto_aprovado BIT DEFAULT 1,
    
    -- ═══════════════════════════════════════════
    -- CONSTRAINTS
    -- ═══════════════════════════════════════════
    CONSTRAINT FK_FACT_DESCONTOS_desconto FOREIGN KEY (desconto_id) REFERENCES dim.DIM_DESCONTO(desconto_id),
    CONSTRAINT FK_FACT_DESCONTOS_venda FOREIGN KEY (venda_id) REFERENCES fact.FACT_VENDAS(venda_id),
    CONSTRAINT FK_FACT_DESCONTOS_data FOREIGN KEY (data_aplicacao_id) REFERENCES dim.DIM_DATA(data_id),
    CONSTRAINT FK_FACT_DESCONTOS_cliente FOREIGN KEY (cliente_id) REFERENCES dim.DIM_CLIENTE(cliente_id),
    CONSTRAINT FK_FACT_DESCONTOS_produto FOREIGN KEY (produto_id) REFERENCES dim.DIM_PRODUTO(produto_id),
    
    CONSTRAINT CK_FACT_DESCONTOS_nivel CHECK (nivel_aplicacao IN ('Produto', 'Pedido', 'Frete'))
);
```

### 📈 Métricas Principais

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `valor_desconto_aplicado` | Aditiva | Quanto foi descontado (R$) |
| `valor_sem_desconto` | Aditiva | Valor original |
| `valor_com_desconto` | Aditiva | Valor final pago |
| `impacto_margem` | Aditiva | Redução na margem (R$) |

### 🔍 Análises Suportadas

```sql
-- 1. ROI de campanhas
SELECT 
    d.nome_campanha,
    d.tipo_desconto,
    COUNT(*) AS total_aplicacoes,
    SUM(fd.valor_desconto_aplicado) AS custo_campanha,
    SUM(fd.valor_com_desconto) AS receita_gerada,
    (SUM(fd.valor_com_desconto) / NULLIF(SUM(fd.valor_desconto_aplicado), 0)) AS roi
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.nome_campanha, d.tipo_desconto
ORDER BY roi DESC;

-- 2. Impacto na margem por tipo de desconto
SELECT 
    d.tipo_desconto,
    AVG(fd.margem_antes_desconto) AS margem_media_antes,
    AVG(fd.margem_apos_desconto) AS margem_media_depois,
    AVG(fd.impacto_margem) AS impacto_medio
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.tipo_desconto;

-- 3. Produtos mais descontados
SELECT 
    p.nome_produto,
    p.categoria,
    COUNT(*) AS vezes_descontado,
    AVG(fd.valor_desconto_aplicado) AS desconto_medio
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_PRODUTO p ON fd.produto_id = p.produto_id
GROUP BY p.nome_produto, p.categoria
ORDER BY vezes_descontado DESC;

-- 4. Análise por nível de aplicação
SELECT 
    nivel_aplicacao,
    COUNT(*) AS total_descontos,
    SUM(valor_desconto_aplicado) AS valor_total,
    AVG(valor_desconto_aplicado) AS media_desconto
FROM fact.FACT_DESCONTOS
GROUP BY nivel_aplicacao;
```

### 📝 Características Especiais

- **Relacionamento 1:N** com FACT_VENDAS (uma venda pode ter múltiplos descontos)
- **FK para outra Fact:** `venda_id` aponta para FACT_VENDAS
- **Flexibilidade:** Suporta cenários complexos (cupom + volume + frete)

---

## 📊 Comparação entre Facts

| Característica | FACT_VENDAS | FACT_METAS | FACT_DESCONTOS |
|----------------|-------------|------------|----------------|
| **Tipo** | Transacional | Periodic Snapshot | Eventos |
| **Granularidade** | 1 item/venda | 1 meta/vendedor/mês | 1 desconto aplicado |
| **Frequência** | Contínua | Mensal | Conforme aplicação |
| **Volume** | Alto (milhões) | Médio (milhares) | Médio (centenas de milhares) |
| **Crescimento** | Contínuo | Previsível | Variável |
| **Atualizações** | Raras (devoluções) | Mensal (fechamento) | Sem atualização |
| **FKs** | 5 dimensões | 2 dimensões | 5 dimensões + 1 fact |
| **Métricas** | 10+ campos | 8+ campos | 7+ campos |

---

## 🎯 Padrões de Consulta

### Pattern 1: Drill-Down Temporal

```sql
-- Ano → Trimestre → Mês → Dia
SELECT 
    d.ano,
    d.trimestre,
    d.mes,
    d.data_completa,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY GROUPING SETS (
    (d.ano),
    (d.ano, d.trimestre),
    (d.ano, d.trimestre, d.mes),
    (d.ano, d.trimestre, d.mes, d.data_completa)
);
```

### Pattern 2: Comparação Período Anterior

```sql
-- Vendas: Mês atual vs mês anterior
SELECT 
    d.ano,
    d.mes,
    SUM(fv.valor_total_liquido) AS receita_atual,
    LAG(SUM(fv.valor_total_liquido)) OVER (ORDER BY d.ano, d.mes) AS receita_anterior,
    (SUM(fv.valor_total_liquido) - LAG(SUM(fv.valor_total_liquido)) OVER (ORDER BY d.ano, d.mes)) AS variacao
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.ano, d.mes
ORDER BY d.ano, d.mes;
```

### Pattern 3: Análise Multi-Dimensional

```sql
-- Receita por: Produto × Região × Tempo
SELECT 
    p.categoria,
    r.regiao_pais,
    d.ano,
    d.trimestre,
    SUM(fv.valor_total_liquido) AS receita,
    COUNT(*) AS total_vendas
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY CUBE(p.categoria, r.regiao_pais, d.ano, d.trimestre);
```

### Pattern 4: Join entre Facts

```sql
-- Análise integrada: Vendas com Descontos
SELECT 
    fv.venda_id,
    fv.numero_pedido,
    fv.valor_total_bruto,
    fv.valor_total_liquido,
    COUNT(fd.desconto_aplicado_id) AS qtd_descontos,
    SUM(fd.valor_desconto_aplicado) AS total_descontos
FROM fact.FACT_VENDAS fv
LEFT JOIN fact.FACT_DESCONTOS fd ON fv.venda_id = fd.venda_id
GROUP BY fv.venda_id, fv.numero_pedido, fv.valor_total_bruto, fv.valor_total_liquido
HAVING COUNT(fd.desconto_aplicado_id) > 1  -- Apenas vendas com múltiplos descontos
ORDER BY total_descontos DESC;

Analisando o arquivo 03_fatos.md, posso ver que você parou no Pattern 4: Join entre Facts, especificamente na query SQL que estava sendo construída. A query foi interrompida na linha do GROUP BY.
Vou retornar apenas o que faltou para completar a documentação:

sql_pedido, fv.valor_total_bruto, fv.valor_total_liquido
HAVING COUNT(fd.desconto_aplicado_id) > 1  -- Apenas vendas com múltiplos descontos
ORDER BY total_descontos DESC;
Pattern 5: Ranking e Percentis
sql-- Top 20% de produtos por receita (Análise Pareto)
WITH produto_receita AS (
    SELECT 
        p.produto_id,
        p.nome_produto,
        p.categoria,
        SUM(fv.valor_total_liquido) AS receita,
        NTILE(5) OVER (ORDER BY SUM(fv.valor_total_liquido) DESC) AS quintil
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
    GROUP BY p.produto_id, p.nome_produto, p.categoria
)
SELECT 
    nome_produto,
    categoria,
    receita,
    quintil,
    CASE 
        WHEN quintil = 1 THEN 'A - Top 20%'
        WHEN quintil = 2 THEN 'B - Próximos 20%'
        WHEN quintil = 3 THEN 'C - Médio 20%'
        WHEN quintil = 4 THEN 'D - Abaixo Médio'
        ELSE 'E - Bottom 20%'
    END AS classificacao
FROM produto_receita
WHERE quintil = 1  -- Apenas top 20%
ORDER BY receita DESC;
Pattern 6: Performance vs Meta
sql-- Análise integrada: Vendas realizadas vs Metas
SELECT 
    v.nome_vendedor,
    v.nome_equipe,
    d.ano,
    d.mes,
    fm.valor_meta,
    fm.valor_realizado AS meta_registrada,
    SUM(fv.valor_total_liquido) AS vendas_detalhadas,
    fm.percentual_atingido,
    CASE 
        WHEN fm.meta_batida = 1 THEN '✅ Bateu'
        ELSE '❌ Não bateu'
    END AS status
FROM fact.FACT_METAS fm
JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
JOIN dim.DIM_DATA d ON fm.data_id = d.data_id
LEFT JOIN fact.FACT_VENDAS fv ON fv.vendedor_id = fm.vendedor_id 
    AND YEAR(fv.data_id) = d.ano 
    AND MONTH(fv.data_id) = d.mes
GROUP BY v.nome_vendedor, v.nome_equipe, d.ano, d.mes, 
         fm.valor_meta, fm.valor_realizado, fm.percentual_atingido, fm.meta_batida
ORDER BY d.ano DESC, d.mes DESC, fm.percentual_atingido DESC;

📋 Checklist de Validação
Validações de Integridade
sql-- 1. Verificar órfãos em FACT_VENDAS
SELECT COUNT(*) AS vendas_orfas
FROM fact.FACT_VENDAS fv
WHERE NOT EXISTS (SELECT 1 FROM dim.DIM_DATA d WHERE d.data_id = fv.data_id)
   OR NOT EXISTS (SELECT 1 FROM dim.DIM_CLIENTE c WHERE c.cliente_id = fv.cliente_id)
   OR NOT EXISTS (SELECT 1 FROM dim.DIM_PRODUTO p WHERE p.produto_id = fv.produto_id);
-- Esperado: 0

-- 2. Validar cálculos em FACT_VENDAS
SELECT COUNT(*) AS inconsistencias_valor
FROM fact.FACT_VENDAS
WHERE valor_total_liquido <> (valor_total_bruto - valor_total_descontos);
-- Esperado: 0

-- 3. Validar unicidade em FACT_METAS
SELECT vendedor_id, data_id, tipo_periodo, COUNT(*)
FROM fact.FACT_METAS
GROUP BY vendedor_id, data_id, tipo_periodo
HAVING COUNT(*) > 1;
-- Esperado: 0 linhas

-- 4. Verificar coerência meta_batida em FACT_METAS
SELECT COUNT(*) AS inconsistencias_meta
FROM fact.FACT_METAS
WHERE (meta_batida = 1 AND percentual_atingido < 100)
   OR (meta_batida = 0 AND percentual_atingido >= 100);
-- Esperado: 0

-- 5. Validar relacionamento FACT_DESCONTOS → FACT_VENDAS
SELECT COUNT(*) AS descontos_sem_venda
FROM fact.FACT_DESCONTOS fd
WHERE NOT EXISTS (
    SELECT 1 FROM fact.FACT_VENDAS fv WHERE fv.venda_id = fd.venda_id
);
-- Esperado: 0
Estatísticas de Volume
sql-- Resumo de registros por tabela fato
SELECT 
    'FACT_VENDAS' AS tabela,
    COUNT(*) AS total_registros,
    MIN(data_id) AS periodo_inicio,
    MAX(data_id) AS periodo_fim,
    COUNT(DISTINCT cliente_id) AS entidades_unicas
FROM fact.FACT_VENDAS

UNION ALL

SELECT 
    'FACT_METAS',
    COUNT(*),
    MIN(data_id),
    MAX(data_id),
    COUNT(DISTINCT vendedor_id)
FROM fact.FACT_METAS

UNION ALL

SELECT 
    'FACT_DESCONTOS',
    COUNT(*),
    MIN(data_aplicacao_id),
    MAX(data_aplicacao_id),
    COUNT(DISTINCT desconto_id)
FROM fact.FACT_DESCONTOS;

🎓 Boas Práticas
✅ Fazer

✅ Usar BIGINT para PKs de facts (crescem muito)
✅ Criar índices em todas FKs
✅ Armazenar métricas calculadas frequentes (performance)
✅ Particionar facts grandes por data
✅ Implementar constraints de integridade
✅ Documentar fórmulas de cálculo
✅ Manter auditoria (data_inclusao, data_atualizacao)

❌ Evitar

❌ Usar VARCHAR para chaves numéricas
❌ Atualizar facts transacionais após inserção
❌ Misturar granularidades na mesma fact
❌ Deixar FKs sem índices
❌ Calcular métricas sempre na query (armazenar as principais)
❌ Ignorar constraints de validação
❌ Criar facts sem definir granularidade claramente


🔮 Expansões Futuras
Facts Adicionais Planejadas
FACT_ESTOQUE

Granularidade: 1 produto × 1 dia
Tipo: Periodic Snapshot
Métricas: quantidade_disponivel, valor_estoque, dias_cobertura
Análises: Giro de estoque, ruptura, excesso

FACT_LOGISTICA

Granularidade: 1 envio
Tipo: Accumulating Snapshot
Métricas: prazo_entrega, custo_frete, status_entrega
Análises: SLA de entrega, custo por região

FACT_ATENDIMENTO

Granularidade: 1 ticket de suporte
Tipo: Accumulating Snapshot
Métricas: tempo_resposta, tempo_resolucao, satisfacao
Análises: Qualidade do atendimento, motivos de contato


📚 Referências

Dimensões - Especificação de todas as dimensões
Relacionamentos - Mapa de FKs e integridade
Queries de Exemplo - 22 exemplos práticos
Decisões de Design - Justificativas


<div align="center">
⬆ Voltar ao topo
Modelagem baseada em Ralph Kimball - The Data Warehouse Toolkit
Facts otimizadas para análises de alta performance
</div>

