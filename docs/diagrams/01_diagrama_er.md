# 🗺️ Diagrama Entidade-Relacionamento (ER)

> Modelo visual completo do Data Warehouse E-commerce

## 📋 Índice

- [Diagrama Completo (Star Schema)](#diagrama-completo-star-schema)
- [Diagrama por Processo de Negócio](#diagrama-por-processo-de-negócio)
- [Relacionamentos Detalhados](#relacionamentos-detalhados)
- [Cardinalidades](#cardinalidades)
- [Dependências e Ordem de Criação](#dependências-e-ordem-de-criação)
- [Legenda](#legenda)

---

## 🌟 Diagrama Completo (Star Schema)

### Visão Geral - Todas as Tabelas

```mermaid
erDiagram
    %% ============================================
    %% DIMENSÕES
    %% ============================================
    
    DIM_DATA {
        int data_id PK
        date data_completa UK
        int ano
        int trimestre
        int mes
        varchar nome_mes
        int dia_mes
        int dia_ano
        int dia_semana
        varchar nome_dia_semana
        bit eh_fim_de_semana
        bit eh_feriado
        varchar nome_feriado
    }
    
    DIM_CLIENTE {
        int cliente_id PK
        int cliente_original_id UK
        varchar nome_cliente
        varchar email UK
        varchar tipo_cliente
        varchar segmento
        varchar cidade
        char estado
        varchar pais
        date data_cadastro
        date data_ultima_compra
        bit eh_ativo
    }
    
    DIM_PRODUTO {
        int produto_id PK
        int produto_original_id UK
        varchar codigo_sku UK
        varchar nome_produto
        varchar categoria
        varchar subcategoria
        varchar marca
        int fornecedor_id
        varchar nome_fornecedor
        decimal peso_kg
        decimal preco_sugerido
        decimal custo_medio
        bit eh_ativo
    }
    
    DIM_REGIAO {
        int regiao_id PK
        int regiao_original_id UK
        varchar pais
        varchar regiao_pais
        char estado
        varchar nome_estado
        varchar cidade
        varchar codigo_ibge
        int populacao_estimada
        decimal area_km2
        decimal pib_per_capita
        decimal idh
        decimal latitude
        decimal longitude
    }
    
    DIM_EQUIPE {
        int equipe_id PK
        int equipe_original_id UK
        varchar nome_equipe UK
        varchar tipo_equipe
        varchar regional
        char estado_sede
        int lider_equipe_id FK
        varchar nome_lider
        decimal meta_mensal_equipe
        int qtd_membros_atual
        bit eh_ativa
    }
    
    DIM_VENDEDOR {
        int vendedor_id PK
        int vendedor_original_id UK
        varchar nome_vendedor
        varchar matricula UK
        varchar email UK
        varchar cargo
        int equipe_id FK
        varchar nome_equipe
        int gerente_id FK
        varchar nome_gerente
        char estado_atuacao
        decimal meta_mensal_base
        decimal percentual_comissao_padrao
        date data_contratacao
        bit eh_ativo
        bit eh_lider
    }
    
    DIM_DESCONTO {
        int desconto_id PK
        int desconto_original_id UK
        varchar codigo_desconto UK
        varchar nome_campanha
        varchar tipo_desconto
        varchar metodo_desconto
        decimal valor_desconto
        decimal min_valor_compra_regra
        date data_inicio_validade
        date data_fim_validade
        varchar situacao
    }
    
    %% ============================================
    %% TABELAS FATO
    %% ============================================
    
    FACT_VENDAS {
        bigint venda_id PK
        int data_id FK
        int cliente_id FK
        int produto_id FK
        int regiao_id FK
        int vendedor_id FK
        int quantidade_vendida
        decimal preco_unitario_tabela
        decimal valor_total_bruto
        decimal valor_total_descontos
        decimal valor_total_liquido
        decimal custo_total
        int quantidade_devolvida
        decimal valor_devolvido
        decimal percentual_comissao
        decimal valor_comissao
        varchar numero_pedido
        bit teve_desconto
        datetime data_inclusao
    }
    
    FACT_METAS {
        bigint meta_id PK
        int vendedor_id FK
        int data_id FK
        decimal valor_meta
        int quantidade_meta
        decimal valor_realizado
        int quantidade_realizada
        decimal percentual_atingido
        decimal gap_meta
        decimal ticket_medio_realizado
        int ranking_periodo
        varchar quartil_performance
        bit meta_batida
        bit meta_superada
        bit eh_periodo_fechado
        varchar tipo_periodo
        datetime data_inclusao
    }
    
    FACT_DESCONTOS {
        bigint desconto_aplicado_id PK
        int desconto_id FK
        bigint venda_id FK
        int data_aplicacao_id FK
        int cliente_id FK
        int produto_id FK
        varchar nivel_aplicacao
        decimal valor_desconto_aplicado
        decimal valor_sem_desconto
        decimal valor_com_desconto
        decimal margem_antes_desconto
        decimal margem_apos_desconto
        decimal impacto_margem
        varchar numero_pedido
        bit desconto_aprovado
        datetime data_inclusao
    }
    
    %% ============================================
    %% RELACIONAMENTOS
    %% ============================================
    
    %% FACT_VENDAS
    FACT_VENDAS }o--|| DIM_DATA : "acontece em"
    FACT_VENDAS }o--|| DIM_CLIENTE : "comprado por"
    FACT_VENDAS }o--|| DIM_PRODUTO : "contém"
    FACT_VENDAS }o--|| DIM_REGIAO : "entregue em"
    FACT_VENDAS }o--o| DIM_VENDEDOR : "vendido por (opcional)"
    
    %% FACT_METAS
    FACT_METAS }o--|| DIM_VENDEDOR : "meta de"
    FACT_METAS }o--|| DIM_DATA : "período de"
    
    %% FACT_DESCONTOS
    FACT_DESCONTOS }o--|| DIM_DESCONTO : "tipo de desconto"
    FACT_DESCONTOS }o--|| FACT_VENDAS : "aplicado em (fact-to-fact)"
    FACT_DESCONTOS }o--|| DIM_DATA : "aplicado em (data)"
    FACT_DESCONTOS }o--|| DIM_CLIENTE : "para cliente (desnorm)"
    FACT_DESCONTOS }o--o| DIM_PRODUTO : "em produto (opcional)"
    
    %% Relacionamentos entre Dimensões
    DIM_VENDEDOR }o--o| DIM_EQUIPE : "pertence a"
    DIM_VENDEDOR }o--o| DIM_VENDEDOR : "subordinado a (self-join)"
    DIM_EQUIPE }o--o| DIM_VENDEDOR : "liderada por (circular)"
```

---

## 📊 Diagrama por Processo de Negócio

### 1️⃣ Processo: Vendas Transacionais

```mermaid
erDiagram
    %% Foco em FACT_VENDAS e suas dimensões
    
    FACT_VENDAS {
        bigint venda_id PK "Chave surrogate"
        int data_id FK "QUANDO?"
        int cliente_id FK "QUEM comprou?"
        int produto_id FK "O QUE comprou?"
        int regiao_id FK "ONDE entregar?"
        int vendedor_id FK "QUEM vendeu? (NULL=direto)"
        int quantidade_vendida "Métrica"
        decimal valor_total_liquido "Métrica principal"
        decimal custo_total "Métrica"
        varchar numero_pedido "Degenerate Dim"
        bit teve_desconto "Flag"
    }
    
    DIM_DATA {
        int data_id PK
        date data_completa
        int ano
        int mes
        varchar nome_mes
        int dia_semana
        bit eh_fim_de_semana
    }
    
    DIM_CLIENTE {
        int cliente_id PK
        varchar nome_cliente
        varchar tipo_cliente
        varchar segmento
        varchar cidade
        char estado
    }
    
    DIM_PRODUTO {
        int produto_id PK
        varchar nome_produto
        varchar categoria
        varchar subcategoria
        varchar marca
        varchar nome_fornecedor
    }
    
    DIM_REGIAO {
        int regiao_id PK
        varchar regiao_pais
        char estado
        varchar cidade
        decimal idh
    }
    
    DIM_VENDEDOR {
        int vendedor_id PK
        varchar nome_vendedor
        varchar cargo
        int equipe_id FK
    }
    
    FACT_VENDAS }o--|| DIM_DATA : "N:1"
    FACT_VENDAS }o--|| DIM_CLIENTE : "N:1"
    FACT_VENDAS }o--|| DIM_PRODUTO : "N:1"
    FACT_VENDAS }o--|| DIM_REGIAO : "N:1"
    FACT_VENDAS }o--o| DIM_VENDEDOR : "N:0..1 (opcional)"
```

**Granularidade:** 1 linha = 1 item vendido em 1 pedido  
**Tipo:** Transaction Fact Table  
**Volume:** Alto (milhões de registros)

---

### 2️⃣ Processo: Gestão de Metas

```mermaid
erDiagram
    %% Foco em FACT_METAS
    
    FACT_METAS {
        bigint meta_id PK
        int vendedor_id FK "Para QUEM?"
        int data_id FK "QUANDO? (1º dia mês)"
        decimal valor_meta "Objetivo"
        decimal valor_realizado "Atingido"
        decimal percentual_atingido "% Meta"
        decimal gap_meta "Diferença"
        bit meta_batida "Flag sucesso"
        varchar tipo_periodo "Mensal/Trimestral"
    }
    
    DIM_VENDEDOR {
        int vendedor_id PK
        varchar nome_vendedor
        varchar cargo
        int equipe_id FK
        decimal meta_mensal_base
    }
    
    DIM_DATA {
        int data_id PK
        date data_completa
        int ano
        int mes
        varchar nome_mes
    }
    
    DIM_EQUIPE {
        int equipe_id PK
        varchar nome_equipe
        varchar regional
        decimal meta_mensal_equipe
    }
    
    FACT_METAS }o--|| DIM_VENDEDOR : "N:1"
    FACT_METAS }o--|| DIM_DATA : "N:1"
    DIM_VENDEDOR }o--o| DIM_EQUIPE : "N:0..1"
```

**Granularidade:** 1 linha = 1 meta de 1 vendedor em 1 período  
**Tipo:** Periodic Snapshot Fact Table  
**Volume:** Baixo/Médio (controlado)

**Constraint Único:**
```sql
UNIQUE (vendedor_id, data_id, tipo_periodo)
-- Garante: 1 vendedor não tem 2 metas no mesmo período
```

---

### 3️⃣ Processo: Descontos e Campanhas

```mermaid
erDiagram
    %% Foco em FACT_DESCONTOS
    
    FACT_DESCONTOS {
        bigint desconto_aplicado_id PK
        int desconto_id FK "QUAL campanha?"
        bigint venda_id FK "Em QUAL venda?"
        int data_aplicacao_id FK "QUANDO aplicado?"
        int cliente_id FK "QUEM usou? (desnorm)"
        int produto_id FK "EM QUE? (opcional)"
        decimal valor_desconto_aplicado "Métrica"
        decimal impacto_margem "Métrica"
        varchar nivel_aplicacao "Produto/Pedido/Frete"
    }
    
    DIM_DESCONTO {
        int desconto_id PK
        varchar codigo_desconto
        varchar nome_campanha
        varchar tipo_desconto
        decimal valor_desconto
        date data_inicio_validade
        date data_fim_validade
    }
    
    FACT_VENDAS {
        bigint venda_id PK
        decimal valor_total_liquido
        varchar numero_pedido
    }
    
    DIM_DATA {
        int data_id PK
        date data_completa
    }
    
    DIM_CLIENTE {
        int cliente_id PK
        varchar nome_cliente
        varchar segmento
    }
    
    DIM_PRODUTO {
        int produto_id PK
        varchar nome_produto
    }
    
    FACT_DESCONTOS }o--|| DIM_DESCONTO : "N:1"
    FACT_DESCONTOS }o--|| FACT_VENDAS : "N:1 (fact-to-fact!)"
    FACT_DESCONTOS }o--|| DIM_DATA : "N:1"
    FACT_DESCONTOS }o--|| DIM_CLIENTE : "N:1"
    FACT_DESCONTOS }o--o| DIM_PRODUTO : "N:0..1"
```

**Granularidade:** 1 linha = 1 desconto aplicado em 1 venda  
**Tipo:** Transaction Fact Table  
**Volume:** Variável (depende de campanhas)

**Relacionamento Especial:**
- ⚠️ **FACT-to-FACT:** `FACT_DESCONTOS.venda_id` → `FACT_VENDAS.venda_id`
- Permite múltiplos descontos por venda

---

## 🔗 Relacionamentos Detalhados

### Matriz de Relacionamentos

| De → Para | Tipo | Cardinalidade | Obrigatório? | Descrição |
|-----------|------|---------------|--------------|-----------|
| **FACT_VENDAS → DIM_DATA** | FK | N:1 | ✅ Sim | Cada venda acontece em uma data |
| **FACT_VENDAS → DIM_CLIENTE** | FK | N:1 | ✅ Sim | Cada venda tem um comprador |
| **FACT_VENDAS → DIM_PRODUTO** | FK | N:1 | ✅ Sim | Cada item vendido é um produto |
| **FACT_VENDAS → DIM_REGIAO** | FK | N:1 | ✅ Sim | Cada venda tem destino de entrega |
| **FACT_VENDAS → DIM_VENDEDOR** | FK | N:0..1 | ❌ Não | Venda pode não ter vendedor (e-commerce direto) |
| **FACT_METAS → DIM_VENDEDOR** | FK | N:1 | ✅ Sim | Cada meta pertence a um vendedor |
| **FACT_METAS → DIM_DATA** | FK | N:1 | ✅ Sim | Cada meta é de um período específico |
| **FACT_DESCONTOS → DIM_DESCONTO** | FK | N:1 | ✅ Sim | Cada desconto aplicado é de uma campanha |
| **FACT_DESCONTOS → FACT_VENDAS** | FK | N:1 | ✅ Sim | Desconto aplicado em uma venda específica |
| **FACT_DESCONTOS → DIM_DATA** | FK | N:1 | ✅ Sim | Data de aplicação do desconto |
| **FACT_DESCONTOS → DIM_CLIENTE** | FK | N:1 | ✅ Sim | Cliente que usou o desconto (desnormalizado) |
| **FACT_DESCONTOS → DIM_PRODUTO** | FK | N:0..1 | ❌ Não | Produto com desconto (NULL se for desconto no pedido/frete) |
| **DIM_VENDEDOR → DIM_EQUIPE** | FK | N:0..1 | ❌ Não | Vendedor pode estar sem equipe temporariamente |
| **DIM_VENDEDOR → DIM_VENDEDOR** | FK (self) | N:0..1 | ❌ Não | Hierarquia gerencial (gerente_id) |
| **DIM_EQUIPE → DIM_VENDEDOR** | FK | 1:0..1 | ❌ Não | Líder da equipe (circular reference) |

---

## 📏 Cardinalidades

### Notação Utilizada

```
Símbolo │ Significado
────────┼─────────────────────────
  ||    │ Exatamente 1 (obrigatório)
  |o    │ Zero ou 1 (opcional)
  }|    │ Muitos (N)
  }o    │ Zero ou muitos
```

### Exemplos de Leitura

```mermaid
erDiagram
    FACT_VENDAS }o--|| DIM_CLIENTE : "N:1 obrigatório"
    FACT_VENDAS }o--o| DIM_VENDEDOR : "N:0..1 opcional"
    DIM_VENDEDOR }o--o| DIM_EQUIPE : "N:0..1 opcional"
```

**Interpretação:**

1. **FACT_VENDAS }o--|| DIM_CLIENTE**
   - "Muitas vendas (N) pertencem a exatamente 1 cliente"
   - FK obrigatória (NOT NULL)

2. **FACT_VENDAS }o--o| DIM_VENDEDOR**
   - "Muitas vendas (N) podem ter 0 ou 1 vendedor"
   - FK opcional (NULL permitido)

3. **DIM_VENDEDOR }o--o| DIM_EQUIPE**
   - "Muitos vendedores (N) podem pertencer a 0 ou 1 equipe"
   - Vendedor pode estar sem equipe

---

## 🏗️ Dependências e Ordem de Criação

### Grafo de Dependências

```mermaid
graph TD
    A[1. DIM_DATA] -->|Sem dependências| Z[Pode criar primeiro]
    B[2. DIM_CLIENTE] -->|Sem dependências| Z
    C[3. DIM_PRODUTO] -->|Sem dependências| Z
    D[4. DIM_REGIAO] -->|Sem dependências| Z
    E[5. DIM_DESCONTO] -->|Sem dependências| Z
    
    F[6. DIM_EQUIPE] -->|Criar SEM FK lider_equipe_id| Z
    
    G[7. DIM_VENDEDOR] -->|Depende de DIM_EQUIPE| F
    
    H[8. Adicionar FK lider_equipe_id] -->|Depende de DIM_VENDEDOR| G
    
    I[9. FACT_VENDAS] -->|Depende de todas dimensões| A
    I -->|Depende de todas dimensões| B
    I -->|Depende de todas dimensões| C
    I -->|Depende de todas dimensões| D
    I -->|Depende de DIM_VENDEDOR| G
    
    J[10. FACT_METAS] -->|Depende de DIM_VENDEDOR| G
    J -->|Depende de DIM_DATA| A
    
    K[11. FACT_DESCONTOS] -->|Depende de FACT_VENDAS| I
    K -->|Depende de DIM_DESCONTO| E
    K -->|Depende de outras dims| A
    K -->|Depende de outras dims| B
    K -->|Depende de outras dims| C
```

### Ordem Correta de Execução

```sql
-- ═══════════════════════════════════════════════
-- ETAPA 1: Dimensões independentes (sem FKs)
-- ═══════════════════════════════════════════════
CREATE TABLE dim.DIM_DATA (...);
CREATE TABLE dim.DIM_CLIENTE (...);
CREATE TABLE dim.DIM_PRODUTO (...);
CREATE TABLE dim.DIM_REGIAO (...);
CREATE TABLE dim.DIM_DESCONTO (...);

-- ═══════════════════════════════════════════════
-- ETAPA 2: DIM_EQUIPE SEM FK circular
-- ═══════════════════════════════════════════════
CREATE TABLE dim.DIM_EQUIPE (
    equipe_id INT PRIMARY KEY,
    lider_equipe_id INT NULL  -- SEM FK ainda!
    -- ... outros campos
);

-- ═══════════════════════════════════════════════
-- ETAPA 3: DIM_VENDEDOR (depende de DIM_EQUIPE)
-- ═══════════════════════════════════════════════
CREATE TABLE dim.DIM_VENDEDOR (
    vendedor_id INT PRIMARY KEY,
    equipe_id INT,
    gerente_id INT,  -- self-join
    CONSTRAINT FK_VENDEDOR_equipe 
        FOREIGN KEY (equipe_id) REFERENCES dim.DIM_EQUIPE(equipe_id),
    CONSTRAINT FK_VENDEDOR_gerente 
        FOREIGN KEY (gerente_id) REFERENCES dim.DIM_VENDEDOR(vendedor_id)
);

-- ═══════════════════════════════════════════════
-- ETAPA 4: Adicionar FK circular em DIM_EQUIPE
-- ═══════════════════════════════════════════════
ALTER TABLE dim.DIM_EQUIPE
ADD CONSTRAINT FK_EQUIPE_lider 
    FOREIGN KEY (lider_equipe_id) 
    REFERENCES dim.DIM_VENDEDOR(vendedor_id);

-- ═══════════════════════════════════════════════
-- ETAPA 5: FACT_VENDAS (depende de todas dims)
-- ═══════════════════════════════════════════════
CREATE TABLE fact.FACT_VENDAS (...);

-- ═══════════════════════════════════════════════
-- ETAPA 6: FACT_METAS (depende de VENDEDOR e DATA)
-- ═══════════════════════════════════════════════
CREATE TABLE fact.FACT_METAS (...);

-- ═══════════════════════════════════════════════
-- ETAPA 7: FACT_DESCONTOS (depende de FACT_VENDAS!)
-- ═══════════════════════════════════════════════
CREATE TABLE fact.FACT_DESCONTOS (...);
```

---

## 🎨 Legenda

### Tipos de Relacionamento

| Símbolo | Descrição |
|---------|-----------|
| `}o--||` | Muitos-para-Um (N:1) obrigatório |
| `}o--o|` | Muitos-para-Zero-ou-Um (N:0..1) opcional |
| `||--||` | Um-para-Um (1:1) |
| `}o--o{` | Muitos-para-Muitos (N:M) - evitado em Star Schema |

### Tipos de Chave

| Marcador | Descrição |
|----------|-----------|
| **PK** | Primary Key (Chave Primária) |
| **FK** | Foreign Key (Chave Estrangeira) |
| **UK** | Unique Key (Chave Única) |

### Tipos de Tabela

| Prefixo | Tipo | Descrição |
|---------|------|-----------|
| **DIM_** | Dimensão | Descreve contexto (quem, o que, onde, quando) |
| **FACT_** | Fato | Armazena métricas e eventos mensuráveis |

### Cores no Diagrama (se renderizado)

- 🔵 **Azul:** Dimensões
- 🟢 **Verde:** Tabelas Fato
- 🟡 **Amarelo:** Relacionamentos especiais (self-join, circular, fact-to-fact)

---

## 📊 Estatísticas do Modelo

| Métrica | Valor |
|---------|-------|
| **Total de Tabelas** | 10 (7 dims + 3 facts) |
| **Total de FKs** | 15 |
| **FKs em FACT_VENDAS** | 5 |
| **FKs em FACT_METAS** | 2 |
| **FKs em FACT_DESCONTOS** | 5 (incluindo 1 fact-to-fact) |
| **FKs entre Dimensões** | 3 (1 transitiva + 1 self-join + 1 circular) |
| **Relacionamentos Opcionais (NULL)** | 5 |
| **Relacionamentos Obrigatórios (NOT NULL)** | 10 |

---

## 🔍 Relacionamentos Especiais

### 1️⃣ Self-Join (Hierarquia Gerencial)

```mermaid
erDiagram
    DIM_VENDEDOR {
        int vendedor_id PK
        varchar nome_vendedor
        int gerente_id FK
    }
    
    DIM_VENDEDOR }o--o| DIM_VENDEDOR : "subordinado a"
```

**Uso:**
```sql
-- Hierarquia completa (3 níveis)
SELECT 
    v1.nome_vendedor AS vendedor,
    v2.nome_vendedor AS gerente,
    v3.nome_vendedor AS gerente_do_gerente
FROM dim.DIM_VENDEDOR v1
LEFT JOIN dim.DIM_VENDEDOR v2 ON v1.gerente_id = v2.vendedor_id
LEFT JOIN dim.DIM_VENDEDOR v3 ON v2.gerente_id = v3.vendedor_id;
```

---

### 2️⃣ Relacionamento Circular (DIM_EQUIPE ↔ DIM_VENDEDOR)

```mermaid
erDiagram
    DIM_EQUIPE {
        int equipe_id PK
        int lider_equipe_id FK
    }
    
    DIM_VENDEDOR {
        int vendedor_id PK
        int equipe_id FK
    }
    
    DIM_EQUIPE }o--o| DIM_VENDEDOR : "liderada por"
    DIM_VENDEDOR }o--o| DIM_EQUIPE : "pertence a"
```

**Problema:** Deadlock de criação!

**Solução:** Criar em 3 etapas (ver seção "Ordem de Criação")

---

### 3️⃣ Fact-to-Fact (FACT_DESCONTOS → FACT_VENDAS)

```mermaid
erDiagram
    FACT_VENDAS {
        bigint venda_id PK
        varchar numero_pedido
    }
    
    FACT_DESCONTOS {
        bigint desconto_aplicado_id PK
        bigint venda_id FK
    }
    
    FACT_DESCONTOS }o--|| FACT_VENDAS : "aplicado em"
```

**Por quê?** Uma venda pode ter múltiplos descontos:
```
Venda #123:
├─ Desconto 1: BLACKFRIDAY (-10%)
├─ Desconto 2: VOLUME (-5%)
└─ Desconto 3: FRETE_GRATIS (-R$30)
```

---

## 📚 Referências

- **[Modelagem Completa](../modelagem/02_dimensoes.md)** - Detalhes de todas as dimensões
- **[Tabelas Fato](../modelagem/03_fatos.md)** - Especificação das facts
- **[Relacionamentos](../modelagem/04_relacionamentos.md)** - Mapa de FKs e integridade
- **[Dicionário de Dados](../modelagem/05_dicionario_dados.md)** - Catálogo de campos

---

## 🛠️ Como Usar Este Diagrama

### Visualizar no GitHub
Os diagramas Mermaid são renderizados automaticamente no GitHub. Basta abrir este arquivo `.md` no repositório.

### Exportar como Imagem
1. Copie o código Mermaid
2. Cole em: https://mermaid.live/
3. Exporte como PNG/SVG

### Ferramentas de Modelagem
- **dbdiagram.io** - Converter para DBDiagram
- **draw.io** - Importar e customizar
- **Lucidchart** - Diagramas profissionais

---

<div align="center">

**[⬆ Voltar ao topo](#-diagrama-entidade-relacionamento-er)**

*Diagrama gerado seguindo metodologia Kimball - Star Schema*  
*Última atualização: Janeiro 2026*

</div>
