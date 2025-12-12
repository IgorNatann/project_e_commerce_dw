# 🏗️ Visão Geral da Modelagem

> Arquitetura dimensional do Data Warehouse E-commerce

## 📋 Índice

- [Conceitos Fundamentais](#conceitos-fundamentais)
- [Arquitetura Star Schema](#arquitetura-star-schema)
- [Processos de Negócio](#processos-de-negócio)
- [Granularidade](#granularidade)
- [Hierarquias](#hierarquias)
- [Tipos de Facts](#tipos-de-facts)
- [Metodologia Kimball](#metodologia-kimball)

---

## 🎯 Conceitos Fundamentais

### O que é um Data Warehouse?

Um **Data Warehouse (DW)** é um repositório centralizado de dados **otimizado para análise**, não para transações operacionais. Diferente de um banco de dados transacional (OLTP), um DW:

| OLTP (Sistema Transacional) | OLAP (Data Warehouse) |
|------------------------------|------------------------|
| ❌ Muitas escritas por segundo | ✅ Poucas escritas (batch) |
| ❌ Queries complexas lentas | ✅ Queries analíticas rápidas |
| ❌ Dados normalizados (3NF) | ✅ Dados desnormalizados (star) |
| ❌ Histórico limitado | ✅ Histórico completo |
| ❌ Usuários: aplicações | ✅ Usuários: analistas, BI |

### Modelagem Dimensional vs Relacional

```
┌─────────────────────────────────────────────────────────────────┐
│ MODELO RELACIONAL (3NF) - OLTP                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Clientes ──┬── Pedidos ──┬── ItensPedido ──── Produtos       │
│             │              │                                    │
│             └── Enderecos  └── Pagamentos                      │
│                                                                 │
│  ✅ Sem redundância                                             │
│  ✅ Integridade referencial                                     │
│  ❌ Muitos JOINs para análises                                  │
│  ❌ Performance ruim em agregações                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ MODELO DIMENSIONAL (STAR SCHEMA) - OLAP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│      DIM_DATA    DIM_CLIENTE    DIM_PRODUTO                    │
│           \           |            /                            │
│            \          |           /                             │
│             └──── FACT_VENDAS ───┘                             │
│                       |                                         │
│                  DIM_REGIAO                                     │
│                                                                 │
│  ✅ Queries rápidas (poucos JOINs)                              │
│  ✅ Fácil de entender                                           │
│  ✅ Ótimo para BI tools                                         │
│  ❌ Alguma redundância (aceitável)                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⭐ Arquitetura Star Schema

### Estrutura do Nosso DW

```
                    DIM_DATA (Tempo)
                    ┌─────────────┐
                    │ data_id (PK)│
                    │ ano         │
                    │ trimestre   │
                    │ mes         │
                    └──────┬──────┘
                           │
                           │
    DIM_EQUIPE        DIM_VENDEDOR        DIM_DESCONTO
    ┌───────────┐     ┌───────────┐       ┌───────────┐
    │equipe_id  │◄────┤vendedor_id│       │desconto_id│
    │nome_equipe│     │nome       │       │codigo     │
    └───────────┘     │cargo      │       │campanha   │
                      │equipe_id  │       └─────┬─────┘
                      └─────┬─────┘             │
                            │                   │
                            ▼                   ▼
         ┌──────────────────────────────────────────────┐
         │          FACT_VENDAS (Centro)                │
         ├──────────────────────────────────────────────┤
         │ venda_id (PK)                                │
         │ data_id (FK) ────────────────────────────────┼──►DIM_DATA
         │ cliente_id (FK) ─────────────────────────────┼──►DIM_CLIENTE
         │ produto_id (FK) ─────────────────────────────┼──►DIM_PRODUTO
         │ regiao_id (FK) ──────────────────────────────┼──►DIM_REGIAO
         │ vendedor_id (FK) ────────────────────────────┘
         │─────────────────────────────────────────────│
         │ MÉTRICAS:                                    │
         │ quantidade_vendida                           │
         │ valor_total_liquido                          │
         │ custo_total                                  │
         │ valor_comissao                               │
         └──────────────────────────────────────────────┘
                ▲              ▲              ▲
                │              │              │
     ┌──────────┴──┐  ┌───────┴──────┐  ┌───┴────────┐
     │DIM_CLIENTE  │  │DIM_PRODUTO   │  │DIM_REGIAO  │
     │cliente_id   │  │produto_id    │  │regiao_id   │
     │nome         │  │nome_produto  │  │cidade      │
     │tipo_cliente │  │categoria     │  │estado      │
     │segmento     │  │fornecedor    │  │pais        │
     └─────────────┘  └──────────────┘  └────────────┘


         ┌──────────────────────────────────────┐
         │       FACT_METAS (Periódica)         │
         ├──────────────────────────────────────┤
         │ meta_id (PK)                         │
         │ vendedor_id (FK) ────────────────────┼──►DIM_VENDEDOR
         │ data_id (FK) ────────────────────────┼──►DIM_DATA
         │ valor_meta                           │
         │ valor_realizado                      │
         │ percentual_atingido                  │
         └──────────────────────────────────────┘


         ┌──────────────────────────────────────┐
         │     FACT_DESCONTOS (Eventos)         │
         ├──────────────────────────────────────┤
         │ desconto_aplicado_id (PK)            │
         │ desconto_id (FK) ────────────────────┼──►DIM_DESCONTO
         │ venda_id (FK) ───────────────────────┼──►FACT_VENDAS
         │ data_aplicacao_id (FK) ──────────────┼──►DIM_DATA
         │ valor_desconto_aplicado              │
         │ impacto_margem                       │
         └──────────────────────────────────────┘
```

### Características do Star Schema

#### ✅ **Vantagens**

1. **Performance**: JOINs diretos entre fact e dimensions
2. **Simplicidade**: Fácil de entender e explicar para negócio
3. **Flexibilidade**: Fácil adicionar novas dimensões
4. **BI-Friendly**: Ferramentas de BI reconhecem o padrão
5. **Queries Intuitivas**: SQL simples para análises complexas

#### ⚠️ **Trade-offs**

1. **Redundância**: Informações repetidas nas dimensões (ex: nome_fornecedor em cada produto)
2. **Espaço**: Mais espaço em disco que 3NF normalizada
3. **Atualização**: Mudanças em dimensões requerem cuidado (SCD)

---

## 💼 Processos de Negócio

Nosso DW modela **3 processos de negócio** distintos:

### 1️⃣ **Processo: Vendas (Transacional)**

```
FACT_VENDAS
├─ Granularidade: 1 item vendido em 1 pedido
├─ Frequência: Contínua (muitas vezes por dia)
├─ Tipo: Transaction Fact Table
└─ Perguntas respondidas:
   • Quanto vendemos hoje/mês/ano?
   • Quais produtos mais vendidos?
   • Qual margem de lucro por categoria?
   • Vendas por região geográfica?
   • Taxa de devolução por fornecedor?
```

### 2️⃣ **Processo: Metas de Vendedores (Periódica)**

```
FACT_METAS
├─ Granularidade: 1 meta de 1 vendedor em 1 período
├─ Frequência: Mensal (fechamento de mês)
├─ Tipo: Periodic Snapshot Fact Table
└─ Perguntas respondidas:
   • Quantos % da meta o vendedor atingiu?
   • Ranking de performance por período?
   • Tendência de atingimento ao longo do tempo?
   • Comparação vendedor vs vendedor?
   • Previsão baseada em histórico?
```

### 3️⃣ **Processo: Descontos Aplicados (Eventos)**

```
FACT_DESCONTOS
├─ Granularidade: 1 desconto aplicado em 1 venda
├─ Frequência: Conforme aplicação de cupons
├─ Tipo: Transaction Fact Table (eventos)
└─ Perguntas respondidas:
   • ROI de cada campanha de desconto?
   • Impacto de descontos na margem?
   • Produtos mais descontados?
   • Efetividade por tipo de desconto?
   • Ticket médio com vs sem desconto?
```

---

## 🔬 Granularidade

**Granularidade** é a decisão mais importante na modelagem dimensional!

### O que é Granularidade?

> "O que representa 1 linha da tabela fato?"

```
┌─────────────────────────────────────────────────────────────┐
│ EXEMPLO: FACT_VENDAS                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Granularidade escolhida: "1 item vendido em 1 pedido"      │
│                                                             │
│ Pedido #12345:                                              │
│ • Cliente: João Silva                                       │
│ • Data: 2024-12-10                                          │
│ • Item 1: Notebook Dell (2 unidades)    ← 1 LINHA NA FACT  │
│ • Item 2: Mouse Logitech (1 unidade)    ← 1 LINHA NA FACT  │
│ • Item 3: Teclado Mecânico (1 unidade)  ← 1 LINHA NA FACT  │
│                                                             │
│ Resultado: 3 linhas na FACT_VENDAS para este pedido        │
└─────────────────────────────────────────────────────────────┘
```

### Granularidades Possíveis (e por que escolhemos cada uma)

| Tabela Fato | Granularidade Escolhida | Alternativas Descartadas |
|-------------|-------------------------|--------------------------|
| **FACT_VENDAS** | 1 item por pedido | ❌ 1 pedido completo (perde detalhe de itens)<br>❌ 1 transação de pagamento (mistura conceitos) |
| **FACT_METAS** | 1 meta por vendedor por período | ❌ 1 meta por equipe (perde individual)<br>❌ 1 meta diária (muito granular) |
| **FACT_DESCONTOS** | 1 desconto aplicado | ❌ Agregar na FACT_VENDAS (perde múltiplos descontos)<br>❌ 1 por cupom (perde aplicações) |

### Regra de Ouro

> **"Grão mais fino possível que faça sentido para o negócio"**

✅ **Permite:** Agregar para cima (drill-up)  
❌ **Não permite:** Detalhar para baixo (drill-down)

```
Granular (item) → Agregado (pedido) → Agregado (dia) → Agregado (mês)
    ✅ Possível         ✅ Possível        ✅ Possível
    
Agregado (mês) → Detalhar (dia) → Detalhar (pedido) → Detalhar (item)
    ❌ Impossível       ❌ Impossível      ❌ Impossível
```

---

## 📊 Hierarquias

Hierarquias permitem **drill-down** (detalhar) e **roll-up** (agregar).

### Hierarquia Temporal (DIM_DATA)

```
Ano
 └── Trimestre (Q1, Q2, Q3, Q4)
      └── Mês (Jan, Fev, Mar, ...)
           └── Dia (1, 2, 3, ..., 31)
                └── Dia da Semana (Dom, Seg, ...)
```

**Exemplo de análise:**

```sql
-- Roll-up: Agregar por trimestre
SELECT 
    ano,
    trimestre,
    SUM(valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY ano, trimestre;

-- Drill-down: Detalhar até dia
SELECT 
    d.data_completa,
    SUM(valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano = 2024 AND d.mes = 12
GROUP BY d.data_completa
ORDER BY d.data_completa;
```

### Hierarquia Geográfica (DIM_REGIAO)

```
País (Brasil)
 └── Região (Sudeste, Sul, Nordeste, ...)
      └── Estado (SP, RJ, MG, ...)
           └── Cidade (São Paulo, Campinas, ...)
                └── CEP (01000-000, 01001-000, ...)
```

### Hierarquia de Produtos (DIM_PRODUTO)

```
Categoria (Eletrônicos, Livros, ...)
 └── Subcategoria (Notebooks, Mouses, ...)
      └── Produto (Dell Inspiron 15, ...)
           └── SKU (código único)
```

### Hierarquia Organizacional (DIM_VENDEDOR + DIM_EQUIPE)

```
Empresa
 └── Regional (Sudeste, Sul, ...)
      └── Equipe (Equipe Alpha SP, ...)
           └── Líder (Carlos Silva)
                └── Vendedores (Ana, Roberto, ...)
```

---

## 📈 Tipos de Facts

### 1. Transaction Fact Table (Transacional)

**Características:**
- ✅ Captura eventos de negócio conforme ocorrem
- ✅ Grão mais fino (mais detalhado)
- ✅ Cresce continuamente
- ✅ Permite análises flexíveis

**Exemplo:** `FACT_VENDAS`, `FACT_DESCONTOS`

```sql
-- Cada venda é 1 linha
venda_id | data_id | cliente_id | produto_id | quantidade | valor
---------|---------|------------|------------|------------|-------
    1    |  20241  |     5      |     10     |     2      | 7000
    2    |  20241  |     8      |     12     |     1      | 1500
```

### 2. Periodic Snapshot Fact Table (Snapshot Periódico)

**Características:**
- ✅ Congela estado em intervalos regulares
- ✅ Permite análise de tendências
- ✅ Tamanho previsível (N vendedores × M períodos)
- ⚠️ Não captura mudanças intra-período

**Exemplo:** `FACT_METAS`

```sql
-- 1 linha por vendedor por período
meta_id | vendedor_id | data_id | valor_meta | valor_realizado
--------|-------------|---------|------------|----------------
   1    |      3      |  20241  |   50000    |     52500
   2    |      3      |  20242  |   50000    |     48000
```

### 3. Accumulating Snapshot Fact Table (Snapshot Acumulativo)

**Características:**
- ✅ Rastreia processos com início e fim
- ✅ Múltiplas datas (ex: data_pedido, data_envio, data_entrega)
- ✅ Atualiza a mesma linha conforme processo avança
- ⚠️ Não implementado neste projeto (exemplo futuro: logística)

---

## 🎓 Metodologia Kimball

Nosso DW segue as **4 etapas de Ralph Kimball**:

### 1️⃣ **Selecionar o Processo de Negócio**

✅ Escolhemos: **Vendas**, **Metas** e **Descontos**

### 2️⃣ **Definir a Granularidade**

✅ FACT_VENDAS: 1 item por venda  
✅ FACT_METAS: 1 meta por vendedor por mês  
✅ FACT_DESCONTOS: 1 desconto aplicado

### 3️⃣ **Identificar as Dimensões**

✅ 7 dimensões: Data, Cliente, Produto, Região, Vendedor, Equipe, Desconto

### 4️⃣ **Identificar as Métricas (Facts)**

✅ Vendas: quantidade, valores, custos, devoluções  
✅ Metas: meta, realizado, percentual  
✅ Descontos: valor desconto, impacto margem

---

## 📐 Princípios de Design Aplicados

### ✅ Seguimos

1. **Dimensões Conformadas**: Mesma dimensão (ex: DIM_DATA) compartilhada entre facts
2. **Surrogate Keys**: IDs artificiais (1, 2, 3...) em vez de chaves naturais
3. **Desnormalização**: Dados repetidos em dimensões para performance
4. **SCD Type 1**: Sobrescrever valores (simplicidade para início)
5. **Star Schema**: Fact no centro, dimensions ao redor

### ⚠️ Evitamos

1. ❌ **Snowflake Schema**: Dimensões normalizadas (mais JOINs)
2. ❌ **Métricas em Dimensões**: Dimensões são descritivas, não numéricas
3. ❌ **FKs Transitivas Desnecessárias**: Sem equipe_id na FACT_VENDAS
4. ❌ **Granularidade Mista**: Cada fact tem 1 nível de detalhe consistente

---

## 🎯 Resumo Visual

```
┌─────────────────────────────────────────────────────────────────┐
│ MODELO DIMENSIONAL - E-COMMERCE DW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 📐 7 DIMENSÕES                                                  │
│    ├─ DIM_DATA (tempo)                                          │
│    ├─ DIM_CLIENTE (quem compra)                                 │
│    ├─ DIM_PRODUTO (o que compra)                                │
│    ├─ DIM_REGIAO (onde entrega)                                 │
│    ├─ DIM_VENDEDOR (quem vende)                                 │
│    ├─ DIM_EQUIPE (organização)                                  │
│    └─ DIM_DESCONTO (campanhas)                                  │
│                                                                 │
│ 📊 3 FACTS                                                      │
│    ├─ FACT_VENDAS (transações)                                  │
│    ├─ FACT_METAS (periódica)                                    │
│    └─ FACT_DESCONTOS (eventos)                                  │
│                                                                 │
│ 🎯 GRANULARIDADE                                                │
│    └─ Mais fina possível para flexibilidade                     │
│                                                                 │
│ 🔗 RELACIONAMENTOS                                              │
│    └─ Star Schema: Facts conectam-se a Dimensions              │
│                                                                 │
│ ⭐ METODOLOGIA                                                  │
│    └─ Kimball: dimensional, bottom-up                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Próximos Documentos

- **[Dimensões Detalhadas](02_dimensoes.md)** - Cada dimensão explicada campo a campo
- **[Tabelas Fato](03_fatos.md)** - Métricas e análises possíveis
- **[Relacionamentos](04_relacionamentos.md)** - Mapa completo de FKs
- **[Decisões de Design](../decisoes/01_decisoes_modelagem.md)** - Por que escolhemos assim

---

<div align="center">

**[⬆ Voltar ao topo](#-visão-geral-da-modelagem)**

</div>