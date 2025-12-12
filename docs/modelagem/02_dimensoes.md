# 📐 Dimensões - Documentação Detalhada

> Especificação completa de todas as 7 dimensões do modelo

## 📋 Índice

- [DIM_DATA](#dim_data---dimensão-temporal)
- [DIM_CLIENTE](#dim_cliente---dimensão-cliente)
- [DIM_PRODUTO](#dim_produto---dimensão-produto)
- [DIM_REGIAO](#dim_regiao---dimensão-geográfica)
- [DIM_EQUIPE](#dim_equipe---dimensão-equipe)
- [DIM_VENDEDOR](#dim_vendedor---dimensão-vendedor)
- [DIM_DESCONTO](#dim_desconto---dimensão-desconto)

---

## DIM_DATA - Dimensão Temporal

### 🎯 Propósito
Dimensão mais importante do DW. Permite análises temporais em todos os níveis: dia, semana, mês, trimestre, ano.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_DATA (
    -- Chaves
    data_id INT PRIMARY KEY,           -- Surrogate: formato YYYYMMDD (ex: 20241231)
    
    -- Hierarquia Temporal
    data_completa DATE NOT NULL,       -- 2024-12-31
    ano INT NOT NULL,                  -- 2024
    trimestre INT NOT NULL,            -- 1,2,3,4
    mes INT NOT NULL,                  -- 1-12
    nome_mes VARCHAR(20),              -- "Janeiro", "Fevereiro"
    dia_mes INT NOT NULL,              -- 1-31
    dia_ano INT NOT NULL,              -- 1-365/366
    dia_semana INT NOT NULL,           -- 1=Dom, 7=Sáb
    nome_dia_semana VARCHAR(20),      -- "Segunda", "Terça"
    
    -- Flags
    eh_fim_de_semana BIT,             -- 0=Não, 1=Sim
    eh_feriado BIT,                    -- 0=Não, 1=Sim
    nome_feriado VARCHAR(50),          -- "Natal", "Ano Novo"
    eh_dia_util BIT                    -- 0=Não, 1=Sim (calculado)
);
```

### 🌳 Hierarquia

```
Ano (2024)
 └── Trimestre (Q1, Q2, Q3, Q4)
      └── Mês (Janeiro, Fevereiro, ...)
           └── Dia (1, 2, 3, ..., 31)
                └── Dia da Semana (Segunda, Terça, ...)
```

### 📈 Análises Suportadas

```sql
-- Vendas por trimestre
SELECT d.ano, d.trimestre, SUM(fv.valor_total_liquido)
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.ano, d.trimestre;

-- Sazonalidade por mês
SELECT d.nome_mes, AVG(fv.valor_total_liquido)
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.nome_mes, d.mes
ORDER BY d.mes;

-- Performance em dias úteis vs fins de semana
SELECT 
    CASE WHEN d.eh_fim_de_semana = 1 THEN 'Fim de Semana' ELSE 'Dia Útil' END,
    SUM(fv.valor_total_liquido)
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.eh_fim_de_semana;
```

### 🔍 Chave de Negócio
`data_completa` (DATE) - data natural no formato YYYY-MM-DD

### 📝 Observações
- Populada com 10 anos (2020-2030) na criação
- Feriados nacionais brasileiros inclusos
- View `VW_CALENDARIO_COMPLETO` adiciona campos calculados

---

## DIM_CLIENTE - Dimensão Cliente

### 🎯 Propósito
Descreve **quem compra**. Permite segmentação de clientes e análise geográfica de origem.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_CLIENTE (
    -- Chaves
    cliente_id INT PRIMARY KEY,
    cliente_original_id INT UNIQUE,    -- ID do sistema transacional
    
    -- Identificação
    nome_cliente VARCHAR(200) NOT NULL,
    email VARCHAR(255) UNIQUE,
    
    -- Segmentação
    tipo_cliente VARCHAR(20),          -- 'PF', 'PJ'
    segmento VARCHAR(30),              -- 'Bronze', 'Prata', 'Ouro', 'Platinum'
    
    -- Localização (origem do cliente)
    pais VARCHAR(50),
    estado CHAR(2),
    cidade VARCHAR(100),
    
    -- Temporal
    data_cadastro DATE,
    data_ultima_compra DATE,
    
    -- Status
    eh_ativo BIT DEFAULT 1
);
```

### 🎨 Segmentação

| Tipo Cliente | Descrição | Segmento |
|--------------|-----------|----------|
| **PF** | Pessoa Física | Bronze, Prata, Ouro, Platinum |
| **PJ** | Pessoa Jurídica | Corporativo, Enterprise |

**Regras de Segmentação** (exemplo):
- Bronze: < R$ 1.000 em compras totais
- Prata: R$ 1.000 - R$ 10.000
- Ouro: R$ 10.000 - R$ 50.000
- Platinum: > R$ 50.000

### 📈 Análises Suportadas

```sql
-- Ticket médio por segmento
SELECT 
    c.segmento,
    AVG(fv.valor_total_liquido) AS ticket_medio,
    COUNT(DISTINCT fv.cliente_id) AS clientes_unicos
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_CLIENTE c ON fv.cliente_id = c.cliente_id
GROUP BY c.segmento;

-- Clientes por estado
SELECT c.estado, COUNT(*) AS total_clientes
FROM dim.DIM_CLIENTE c
WHERE c.eh_ativo = 1
GROUP BY c.estado
ORDER BY total_clientes DESC;
```

### 🔍 Chaves de Negócio
- `cliente_original_id` (INT) - ID do sistema CRM
- `email` (VARCHAR) - único por cliente

### 📝 SCD Type
**Type 1** - Sobrescreve valores ao mudar (sem histórico)

---

## DIM_PRODUTO - Dimensão Produto

### 🎯 Propósito
Descreve **o que foi vendido**. Hierarquia de categorização e informações do fornecedor.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_PRODUTO (
    -- Chaves
    produto_id INT PRIMARY KEY,
    produto_original_id INT UNIQUE,
    codigo_sku VARCHAR(50) UNIQUE,
    
    -- Identificação
    nome_produto VARCHAR(200) NOT NULL,
    
    -- Hierarquia de Categorização
    categoria VARCHAR(50),             -- Nível 1: "Eletrônicos", "Livros"
    subcategoria VARCHAR(50),          -- Nível 2: "Notebooks", "Ficção"
    marca VARCHAR(50),
    
    -- Fornecedor (desnormalizado)
    fornecedor_id INT,
    nome_fornecedor VARCHAR(100),
    
    -- Atributos Físicos
    peso_kg DECIMAL(10,2),
    dimensoes VARCHAR(50),             -- "30x20x5 cm"
    
    -- Financeiro
    preco_sugerido DECIMAL(10,2),
    custo_medio DECIMAL(10,2),
    
    -- Status
    eh_ativo BIT DEFAULT 1
);
```

### 🌳 Hierarquia

```
Categoria (Eletrônicos)
 └── Subcategoria (Notebooks)
      └── Marca (Dell, HP, Lenovo)
           └── Produto (Dell Inspiron 15)
                └── SKU (DELL-INSP-15-I5-8GB)
```

### 📈 Análises Suportadas

```sql
-- Top categorias por receita
SELECT 
    p.categoria,
    SUM(fv.valor_total_liquido) AS receita,
    SUM(fv.quantidade_vendida) AS unidades
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.categoria
ORDER BY receita DESC;

-- Margem por fornecedor
SELECT 
    p.nome_fornecedor,
    AVG((fv.valor_total_liquido - fv.custo_total) / NULLIF(fv.valor_total_liquido, 0) * 100) AS margem_media
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.nome_fornecedor;
```

### 🔍 Chaves de Negócio
- `produto_original_id` (INT) - ID do sistema ERP
- `codigo_sku` (VARCHAR) - código único do produto

### 📝 Observações
- `nome_fornecedor` desnormalizado para performance
- View `VW_PRODUTOS_ATIVOS` filtra apenas eh_ativo=1

---

## DIM_REGIAO - Dimensão Geográfica

### 🎯 Propósito
Descreve **onde foi entregue**. Hierarquia geográfica completa com dados demográficos.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_REGIAO (
    -- Chaves
    regiao_id INT PRIMARY KEY,
    regiao_original_id INT UNIQUE,
    
    -- Hierarquia Geográfica
    pais VARCHAR(50) NOT NULL,         -- "Brasil"
    regiao_pais VARCHAR(30),           -- "Sudeste", "Sul", "Nordeste"
    estado CHAR(2) NOT NULL,           -- "SP", "RJ"
    nome_estado VARCHAR(50),           -- "São Paulo"
    cidade VARCHAR(100) NOT NULL,      -- "São Paulo", "Campinas"
    
    -- Códigos
    codigo_ibge VARCHAR(10),
    cep_inicial VARCHAR(10),
    cep_final VARCHAR(10),
    ddd CHAR(2),
    
    -- Dados Demográficos (enriquecimento)
    populacao_estimada INT,
    area_km2 DECIMAL(10,2),
    densidade_demografica DECIMAL(10,2),
    pib_per_capita DECIMAL(10,2),
    idh DECIMAL(4,3),                  -- 0.000 a 1.000
    
    -- Classificação
    tipo_municipio VARCHAR(30),        -- "Capital", "Interior"
    porte_municipio VARCHAR(20),       -- "Grande", "Médio", "Pequeno"
    
    -- Localização
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    fuso_horario VARCHAR(50)
);
```

### 🌳 Hierarquia

```
País (Brasil)
 └── Região (Sudeste, Sul, Nordeste, Norte, Centro-Oeste)
      └── Estado (SP, RJ, MG, ...)
           └── Cidade (São Paulo, Campinas, ...)
                └── CEP (01000-000, 13000-000, ...)
```

### 📈 Análises Suportadas

```sql
-- Vendas por região do país
SELECT 
    r.regiao_pais,
    SUM(fv.valor_total_liquido) AS receita,
    COUNT(DISTINCT fv.cliente_id) AS clientes
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
GROUP BY r.regiao_pais;

-- Correlação IDH x Ticket Médio
SELECT 
    CASE 
        WHEN r.idh >= 0.800 THEN 'Alto IDH (≥0.8)'
        WHEN r.idh >= 0.700 THEN 'Médio IDH (0.7-0.8)'
        ELSE 'Baixo IDH (<0.7)'
    END AS faixa_idh,
    AVG(fv.valor_total_liquido) AS ticket_medio
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
WHERE r.idh IS NOT NULL
GROUP BY CASE 
    WHEN r.idh >= 0.800 THEN 'Alto IDH (≥0.8)'
    WHEN r.idh >= 0.700 THEN 'Médio IDH (0.7-0.8)'
    ELSE 'Baixo IDH (<0.7)'
END;
```

### 🔍 Chave de Negócio
`pais + estado + cidade` (UNIQUE constraint)

### 📝 Observações
- Dados demográficos permitem análises socioeconômicas
- View `VW_HIERARQUIA_GEOGRAFICA` expõe hierarquia completa

---

## DIM_EQUIPE - Dimensão Equipe

### 🎯 Propósito
Organização de vendedores em times comerciais. Suporta análise de performance por equipe.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_EQUIPE (
    -- Chaves
    equipe_id INT PRIMARY KEY,
    equipe_original_id INT UNIQUE,
    
    -- Identificação
    nome_equipe VARCHAR(100) NOT NULL UNIQUE,
    codigo_equipe VARCHAR(20),
    
    -- Classificação
    tipo_equipe VARCHAR(30),           -- 'Vendas Diretas', 'Inside Sales', 'Key Accounts'
    categoria_equipe VARCHAR(30),      -- 'Elite', 'Avançado', 'Intermediário'
    
    -- Localização
    regional VARCHAR(50),              -- 'Sudeste', 'Sul', 'Nordeste'
    estado_sede CHAR(2),
    cidade_sede VARCHAR(100),
    
    -- Liderança (referência para DIM_VENDEDOR)
    lider_equipe_id INT,               -- FK para DIM_VENDEDOR
    nome_lider VARCHAR(150),           -- Desnormalizado
    email_lider VARCHAR(255),
    
    -- Metas
    meta_mensal_equipe DECIMAL(15,2),
    meta_trimestral_equipe DECIMAL(15,2),
    qtd_meta_vendas_mes INT,
    
    -- Composição
    qtd_membros_atual INT,
    qtd_membros_ideal INT,
    
    -- Status
    situacao VARCHAR(20) DEFAULT 'Ativa',
    eh_ativa BIT DEFAULT 1
);
```

### 📈 Análises Suportadas

```sql
-- Ranking de equipes por receita
SELECT 
    e.nome_equipe,
    e.regional,
    SUM(fv.valor_total_liquido) AS receita,
    COUNT(DISTINCT v.vendedor_id) AS vendedores_ativos
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
GROUP BY e.nome_equipe, e.regional
ORDER BY receita DESC;

-- Atingimento de meta por equipe
SELECT 
    e.nome_equipe,
    e.meta_mensal_equipe,
    SUM(fv.valor_total_liquido) AS realizado,
    (SUM(fv.valor_total_liquido) / e.meta_mensal_equipe * 100) AS perc_atingido
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano = 2024 AND d.mes = 12
GROUP BY e.nome_equipe, e.meta_mensal_equipe;
```

### 🔍 Chave de Negócio
`equipe_original_id` (INT)

### 📝 Relacionamentos
- `lider_equipe_id` → `DIM_VENDEDOR.vendedor_id` (circular, resolvido com NULL inicial)

---

## DIM_VENDEDOR - Dimensão Vendedor

### 🎯 Propósito
Força de vendas individual. Permite análise de performance por vendedor, hierarquia gerencial.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_VENDEDOR (
    -- Chaves
    vendedor_id INT PRIMARY KEY,
    vendedor_original_id INT UNIQUE,
    
    -- Identificação
    nome_vendedor VARCHAR(150) NOT NULL,
    nome_exibicao VARCHAR(50),
    matricula VARCHAR(20) UNIQUE,
    email VARCHAR(255) UNIQUE,
    
    -- Cargo e Hierarquia
    cargo VARCHAR(50),                 -- 'Vendedor Júnior', 'Pleno', 'Sênior'
    nivel_senioridade VARCHAR(20),     -- 'Júnior', 'Pleno', 'Sênior'
    departamento VARCHAR(50),
    
    -- Relacionamento com Equipe
    equipe_id INT,                     -- FK para DIM_EQUIPE
    nome_equipe VARCHAR(100),          -- Desnormalizado
    
    -- Hierarquia Gerencial (self-join)
    gerente_id INT,                    -- FK para DIM_VENDEDOR
    nome_gerente VARCHAR(150),
    
    -- Localização
    estado_atuacao CHAR(2),
    cidade_atuacao VARCHAR(100),
    tipo_vendedor VARCHAR(30),         -- 'Interno', 'Externo', 'Remoto'
    
    -- Metas e Comissão
    meta_mensal_base DECIMAL(15,2),
    percentual_comissao_padrao DECIMAL(5,2),
    tipo_comissao VARCHAR(30),
    
    -- Temporal
    data_contratacao DATE,
    data_desligamento DATE,
    
    -- Status
    situacao VARCHAR(20) DEFAULT 'Ativo',
    eh_ativo BIT DEFAULT 1,
    eh_lider BIT DEFAULT 0
);
```

### 🌳 Hierarquia Gerencial (Self-Join)

```
CEO
 └── Diretor Comercial (gerente_id = NULL)
      └── Gerente Regional (gerente_id = Diretor)
           └── Coordenador (gerente_id = Gerente Regional)
                └── Vendedor Sênior (gerente_id = Coordenador)
                     └── Vendedor Júnior (gerente_id = Sênior)
```

### 📈 Análises Suportadas

```sql
-- Top 10 vendedores por receita
SELECT TOP 10
    v.nome_vendedor,
    v.cargo,
    v.nome_equipe,
    SUM(fv.valor_total_liquido) AS receita,
    SUM(fv.valor_comissao) AS comissao_total
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
GROUP BY v.nome_vendedor, v.cargo, v.nome_equipe
ORDER BY receita DESC;

-- Hierarquia gerencial completa
SELECT 
    v.nome_vendedor AS vendedor,
    g.nome_vendedor AS gerente,
    g2.nome_vendedor AS gerente_do_gerente
FROM dim.DIM_VENDEDOR v
LEFT JOIN dim.DIM_VENDEDOR g ON v.gerente_id = g.vendedor_id
LEFT JOIN dim.DIM_VENDEDOR g2 ON g.gerente_id = g2.vendedor_id
WHERE v.eh_ativo = 1;
```

### 🔍 Chaves de Negócio
- `vendedor_original_id` (INT) - ID do sistema RH
- `matricula` (VARCHAR) - matrícula funcional
- `email` (VARCHAR) - email corporativo

### 📝 Relacionamentos
- `equipe_id` → `DIM_EQUIPE.equipe_id`
- `gerente_id` → `DIM_VENDEDOR.vendedor_id` (self-join)

---

## DIM_DESCONTO - Dimensão Desconto

### 🎯 Propósito
Campanhas de desconto e cupons. Permite análise de ROI e efetividade de promoções.

### 📊 Estrutura

```sql
CREATE TABLE dim.DIM_DESCONTO (
    -- Chaves
    desconto_id INT PRIMARY KEY,
    desconto_original_id INT UNIQUE,
    
    -- Identificação
    codigo_desconto VARCHAR(50) UNIQUE, -- "BLACKFRIDAY", "NATAL2024"
    nome_campanha VARCHAR(100),
    
    -- Classificação
    tipo_desconto VARCHAR(30),          -- 'Percentual', 'Valor Fixo', 'Frete Grátis'
    metodo_desconto VARCHAR(30),        -- 'Cupom', 'Automático', 'Negociado'
    
    -- Regras
    valor_desconto DECIMAL(10,2),       -- R$ ou % dependendo do tipo
    min_valor_compra_regra DECIMAL(10,2),
    max_valor_desconto_regra DECIMAL(10,2),
    aplica_em VARCHAR(30),              -- 'Produto', 'Categoria', 'Carrinho'
    
    -- Vigência
    data_inicio_validade DATE,
    data_fim_validade DATE,
    
    -- Status
    situacao VARCHAR(20) DEFAULT 'Ativo'
);
```

### 📈 Análises Suportadas

```sql
-- ROI de campanhas
SELECT 
    d.nome_campanha,
    COUNT(fd.desconto_aplicado_id) AS total_aplicacoes,
    SUM(fd.valor_desconto_aplicado) AS custo_total,
    SUM(fd.valor_com_desconto) AS receita_gerada,
    (SUM(fd.valor_com_desconto) / SUM(fd.valor_desconto_aplicado)) AS roi
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.nome_campanha
ORDER BY roi DESC;

-- Efetividade por tipo de desconto
SELECT 
    d.tipo_desconto,
    AVG(fd.impacto_margem) AS impacto_medio_margem,
    COUNT(*) AS total_aplicacoes
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.tipo_desconto;
```

### 🔍 Chave de Negócio
- `desconto_original_id` (INT) - ID do sistema de promoções
- `codigo_desconto` (VARCHAR) - código do cupom

### 📝 Observações
- View `VW_DESCONTOS_ATIVOS` filtra por vigência atual

---

## 📊 Resumo Comparativo

| Dimensão | Registros Típicos | Crescimento | Hierarquia | SCD Type |
|----------|-------------------|-------------|------------|----------|
| DIM_DATA | 3.650 (10 anos) | Planejado | Ano>Trim>Mês>Dia | N/A |
| DIM_CLIENTE | 10.000 - 1M | Alto | Não | Type 1 |
| DIM_PRODUTO | 1.000 - 100K | Médio | Cat>SubCat>Produto | Type 1 |
| DIM_REGIAO | 100 - 5.000 | Baixo | País>Região>Estado>Cidade | Type 1 |
| DIM_EQUIPE | 10 - 100 | Baixo | Não | Type 1 |
| DIM_VENDEDOR | 50 - 1.000 | Médio | Hierarquia gerencial | Type 1 |
| DIM_DESCONTO | 100 - 1.000 | Médio | Não | Type 1 |

---

<div align="center">

**[⬆ Voltar ao topo](#-dimensões---documentação-detalhada)**

**Próximo:** [Tabelas Fato →](03_fatos.md)

</div>