# 🔍 04_views - Camada de Visualização

## 📋 Visão Geral

Este diretório contém as **11 views** auxiliares do Data Warehouse, que simplificam queries complexas e padronizam o acesso aos dados dimensionais e fatos.

## 🎯 Propósito das Views

As views servem para:
- ✅ Simplificar queries frequentes (eliminar JOINs repetitivos)
- ✅ Incluir campos calculados reutilizáveis
- ✅ Filtrar apenas registros ativos (`eh_ativo=1`)
- ✅ Padronizar acesso aos dados entre equipes
- ✅ Facilitar drill-down e hierarquias
- ✅ Acelerar desenvolvimento de dashboards

## 📁 Estrutura de Arquivos

### Views Dimensionais (6)

| Arquivo | View | Descrição | Base |
|---------|------|-----------|------|
| `01_vw_calendario_completo.sql` | `dim.VW_CALENDARIO_COMPLETO` | Calendário com campos calculados | DIM_DATA |
| `02_vw_produtos_ativos.sql` | `dim.VW_PRODUTOS_ATIVOS` | Produtos ativos + margem | DIM_PRODUTO |
| `03_vw_hierarquia_geografica.sql` | `dim.VW_HIERARQUIA_GEOGRAFICA` | Hierarquia geográfica completa | DIM_REGIAO |
| `05_vw_descontos_ativos.sql` | `dim.VW_DESCONTOS_ATIVOS` | Descontos vigentes | DIM_DESCONTO |
| `06_vw_vendedores_ativos.sql` | `dim.VW_VENDEDORES_ATIVOS` | Vendedores + tempo casa | DIM_VENDEDOR |
| `07_vw_hierarquia_vendedores.sql` | `dim.VW_HIERARQUIA_VENDEDORES` | Hierarquia gerencial | DIM_VENDEDOR |

### Views de Equipes (3)

| Arquivo | View | Descrição | Base |
|---------|------|-----------|------|
| `08_vw_analise_equipe_vendedores.sql` | `dim.VW_ANALISE_EQUIPE_VENDEDORES` | Análise de composição | DIM_EQUIPE + DIM_VENDEDOR |
| `09_vw_equipes_ativas.sql` | `dim.VW_EQUIPES_ATIVAS` | Equipes operacionais | DIM_EQUIPE |
| `10_vw_ranking_equipes_meta.sql` | `dim.VW_RANKING_EQUIPES_META` | Ranking por meta | DIM_EQUIPE |
| `11_vw_analise_regional_equipes.sql` | `dim.VW_ANALISE_REGIONAL_EQUIPES` | Agregação regional | DIM_EQUIPE |

### Views Mestres (1)

| Arquivo | View | Descrição | Base |
|---------|------|-----------|------|
| `04_master_views.sql` | `fact.VW_VENDAS_COMPLETA`<br>`fact.VW_METAS_COMPLETA` | Views analíticas principais | FACT_VENDAS + todas dims<br>FACT_METAS + dims |

### Utilitários

| Arquivo | Descrição |
|---------|-----------|
| `generate_docs.py` | Script Python para gerar documentação |

---

## 🚀 Como Executar

### Opção 1: Todas as views de uma vez

```sql
-- Via SSMS: executar cada script na ordem numérica
-- Ou via sqlcmd:
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i 01_vw_calendario_completo.sql
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i 02_vw_produtos_ativos.sql
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i 03_vw_hierarquia_geografica.sql
-- ... (todas as demais)
```

### Opção 2: View individual

```bash
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i 01_vw_calendario_completo.sql
```

### Opção 3: Via SSMS

1. Abra o script desejado no SSMS
2. Conecte ao banco **DW_ECOMMERCE**
3. Execute (F5)

---

## 📊 Documentação das Views

## 🗓️ VIEWS DIMENSIONAIS

### 1️⃣ VW_CALENDARIO_COMPLETO

**Nome Completo:** `dim.VW_CALENDARIO_COMPLETO`  
**Script:** `01_vw_calendario_completo.sql`  
**Tabela Base:** `dim.DIM_DATA`  

**Propósito:**  
Facilitar análises temporais com campos calculados adicionais.

**Campos Principais:**
- `data_id`, `data_completa` - Chaves
- `ano`, `trimestre`, `mes`, `dia_mes` - Hierarquia temporal
- `nome_mes`, `nome_dia_semana` - Textos descritivos
- `eh_fim_de_semana`, `eh_feriado` - Flags
- **`eh_dia_util`** - ⭐ Calculado: NOT (fim_semana OR feriado)
- **`periodo_desc`** - ⭐ Formatação: "Janeiro/2024" ou "Q1 2024"

**Exemplo de Uso:**
```sql
-- Vendas apenas em dias úteis de 2024
SELECT 
    vc.nome_mes,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.VW_CALENDARIO_COMPLETO vc ON fv.data_id = vc.data_id
WHERE vc.ano = 2024 AND vc.eh_dia_util = 1
GROUP BY vc.nome_mes, vc.mes
ORDER BY vc.mes;

-- Comparação: fim de semana vs dias úteis
SELECT 
    CASE WHEN vc.eh_fim_de_semana = 1 THEN 'Fim de Semana' ELSE 'Dia Útil' END AS tipo_dia,
    COUNT(*) AS total_vendas,
    AVG(fv.valor_total_liquido) AS ticket_medio
FROM fact.FACT_VENDAS fv
JOIN dim.VW_CALENDARIO_COMPLETO vc ON fv.data_id = vc.data_id
GROUP BY vc.eh_fim_de_semana;
```

---

### 2️⃣ VW_PRODUTOS_ATIVOS

**Nome Completo:** `dim.VW_PRODUTOS_ATIVOS`  
**Script:** `02_vw_produtos_ativos.sql`  
**Tabela Base:** `dim.DIM_PRODUTO WHERE eh_ativo=1`  

**Propósito:**  
Listar apenas produtos disponíveis com métricas de margem calculadas.

**Campos Principais:**
- `produto_id`, `codigo_sku` - Chaves
- `nome_produto`, `categoria`, `subcategoria`, `marca` - Descritivos
- `fornecedor_id`, `nome_fornecedor` - Fornecedor
- `preco_sugerido`, `custo_medio` - Valores
- **`margem_sugerida`** - ⭐ (preço - custo) / preço * 100
- **`markup_percentual`** - ⭐ (preço - custo) / custo * 100
- **`hierarquia_completa`** - ⭐ "Categoria > Subcategoria > Produto"
- **`faixa_preco`** - ⭐ Classificação (Premium/Alto/Médio/Baixo)

**Exemplo de Uso:**
```sql
-- Top 10 produtos com maior margem
SELECT TOP 10
    nome_produto,
    categoria,
    preco_sugerido,
    custo_medio,
    margem_sugerida,
    faixa_preco
FROM dim.VW_PRODUTOS_ATIVOS
ORDER BY margem_sugerida DESC;

-- Produtos por faixa de preço
SELECT 
    faixa_preco,
    COUNT(*) AS total_produtos,
    AVG(margem_sugerida) AS margem_media
FROM dim.VW_PRODUTOS_ATIVOS
GROUP BY faixa_preco
ORDER BY margem_media DESC;
```

---

### 3️⃣ VW_HIERARQUIA_GEOGRAFICA

**Nome Completo:** `dim.VW_HIERARQUIA_GEOGRAFICA`  
**Script:** `03_vw_hierarquia_geografica.sql`  
**Tabela Base:** `dim.DIM_REGIAO WHERE eh_ativo=1`  

**Propósito:**  
Facilitar análises geográficas com hierarquia completa e classificações.

**Campos Principais:**
- `regiao_id` - Chave
- `pais`, `regiao_pais`, `estado`, `cidade` - Hierarquia
- `codigo_ibge`, `ddd` - Códigos
- `tipo_municipio`, `porte_municipio` - Classificação
- `populacao_estimada`, `pib_per_capita`, `idh` - Demográficos
- **`hierarquia_completa`** - ⭐ "País > Região > Estado > Cidade"
- **`classificacao_populacional`** - ⭐ Metrópole/Grande/Médio/Pequeno
- **`classificacao_idh`** - ⭐ Muito Alto/Alto/Médio/Baixo
- **`eh_capital`** - ⭐ Flag (tipo_municipio = 'Capital')

**Exemplo de Uso:**
```sql
-- Vendas por região do país
SELECT 
    vhg.regiao_pais,
    COUNT(DISTINCT fv.venda_id) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita,
    AVG(vhg.pib_per_capita) AS pib_medio
FROM fact.FACT_VENDAS fv
JOIN dim.VW_HIERARQUIA_GEOGRAFICA vhg ON fv.regiao_id = vhg.regiao_id
GROUP BY vhg.regiao_pais
ORDER BY receita DESC;

-- Análise por IDH
SELECT 
    classificacao_idh,
    COUNT(DISTINCT regiao_id) AS cidades,
    AVG(populacao_estimada) AS pop_media
FROM dim.VW_HIERARQUIA_GEOGRAFICA
GROUP BY classificacao_idh
ORDER BY classificacao_idh;
```

---

### 5️⃣ VW_DESCONTOS_ATIVOS

**Nome Completo:** `dim.VW_DESCONTOS_ATIVOS`  
**Script:** `05_vw_descontos_ativos.sql`  
**Tabela Base:** `dim.DIM_DESCONTO WHERE situacao='Ativo' AND vigente`  

**Propósito:**  
Listar apenas cupons e descontos vigentes (dentro da validade).

**Campos Principais:**
- `desconto_id`, `codigo_desconto` - Chaves
- `nome_campanha` - Campanha
- `tipo_desconto`, `metodo_desconto` - Classificação
- `valor_desconto` - Valor (% ou R$)
- `data_inicio_validade`, `data_fim_validade` - Vigência
- **`dias_ate_expirar`** - ⭐ DATEDIFF dias até fim
- **`descricao_completa`** - ⭐ Texto formatado do desconto
- **`status_vigencia`** - ⭐ Ativo/Expira Hoje/Expirando

**Exemplo de Uso:**
```sql
-- Cupons disponíveis hoje
SELECT 
    codigo_desconto,
    nome_campanha,
    descricao_completa,
    dias_ate_expirar
FROM dim.VW_DESCONTOS_ATIVOS
ORDER BY dias_ate_expirar;

-- Descontos que expiram esta semana
SELECT *
FROM dim.VW_DESCONTOS_ATIVOS
WHERE dias_ate_expirar <= 7;
```

---

### 6️⃣ VW_VENDEDORES_ATIVOS

**Nome Completo:** `dim.VW_VENDEDORES_ATIVOS`  
**Script:** `06_vw_vendedores_ativos.sql`  
**Tabela Base:** `dim.DIM_VENDEDOR WHERE eh_ativo=1`  

**Propósito:**  
Listar força de vendas ativa com métricas de tempo de casa.

**Campos Principais:**
- `vendedor_id`, `nome_vendedor` - Identificação
- `cargo`, `nivel_senioridade` - Hierarquia
- `equipe_id`, `nome_equipe` - Equipe
- `regional`, `tipo_equipe` - Via JOIN com DIM_EQUIPE
- `gerente_id`, `nome_gerente` - Hierarquia gerencial
- `meta_mensal_base`, `percentual_comissao_padrao` - Metas
- `data_contratacao` - Temporal
- **`meses_na_empresa`** - ⭐ DATEDIFF meses desde contratação
- **`tempo_casa_categoria`** - ⭐ Novato/Júnior/Intermediário/Veterano

**Exemplo de Uso:**
```sql
-- Distribuição por tempo de casa
SELECT 
    tempo_casa_categoria,
    COUNT(*) AS total_vendedores,
    AVG(meta_mensal_base) AS meta_media
FROM dim.VW_VENDEDORES_ATIVOS
GROUP BY tempo_casa_categoria
ORDER BY meta_media DESC;

-- Vendedores por equipe e senioridade
SELECT 
    nome_equipe,
    nivel_senioridade,
    COUNT(*) AS total
FROM dim.VW_VENDEDORES_ATIVOS
GROUP BY nome_equipe, nivel_senioridade
ORDER BY nome_equipe, nivel_senioridade;
```

---

### 7️⃣ VW_HIERARQUIA_VENDEDORES

**Nome Completo:** `dim.VW_HIERARQUIA_VENDEDORES`  
**Script:** `07_vw_hierarquia_vendedores.sql`  
**Tabela Base:** `dim.DIM_VENDEDOR` (self-joins)  

**Propósito:**  
Expor hierarquia gerencial completa (até 2 níveis acima).

**Campos Principais:**
- `vendedor_id`, `nome_vendedor` - Vendedor
- `cargo`, `nivel_senioridade` - Cargo atual
- `equipe_id`, `nome_equipe` - Equipe
- **`gerente_direto_id`** - ID do gerente imediato
- **`gerente_direto_nome`** - Nome do gerente
- **`gerente_direto_cargo`** - Cargo do gerente
- **`gerente_nivel2_id`** - ID do gerente do gerente
- **`gerente_nivel2_nome`** - Nome (nível 2)
- **`nivel_hierarquico`** - ⭐ 1, 2, 3, 4 (profundidade)
- `eh_lider`, `eh_ativo` - Flags

**Exemplo de Uso:**
```sql
-- Estrutura hierárquica completa
SELECT 
    nome_vendedor AS vendedor,
    gerente_direto_nome AS gerente,
    gerente_nivel2_nome AS diretor,
    nivel_hierarquico
FROM dim.VW_HIERARQUIA_VENDEDORES
WHERE eh_ativo = 1
ORDER BY nivel_hierarquico, nome_vendedor;

-- Líderes e seus subordinados
SELECT 
    gerente_direto_nome,
    COUNT(*) AS total_subordinados
FROM dim.VW_HIERARQUIA_VENDEDORES
WHERE gerente_direto_nome IS NOT NULL
GROUP BY gerente_direto_nome
ORDER BY total_subordinados DESC;
```

---

## 👥 VIEWS DE EQUIPES

### 8️⃣ VW_ANALISE_EQUIPE_VENDEDORES

**Nome Completo:** `dim.VW_ANALISE_EQUIPE_VENDEDORES`  
**Script:** `08_vw_analise_equipe_vendedores.sql`  
**Tabela Base:** `dim.DIM_EQUIPE + dim.DIM_VENDEDOR`  

**Propósito:**  
Análise de composição de equipes (quantos vendedores, senioridade, metas).

**Campos Principais:**
- `equipe_id`, `nome_equipe` - Identificação
- `tipo_equipe`, `regional` - Classificação
- **`total_vendedores`** - ⭐ COUNT de vendedores ativos
- **`total_lideres`** - ⭐ COUNT de líderes (eh_lider=1)
- **`soma_metas_individuais`** - ⭐ SUM das metas dos vendedores
- **`media_meta_por_vendedor`** - ⭐ AVG de meta
- `meta_oficial_equipe` - Meta definida da equipe
- **`diferenca_metas`** - ⭐ meta_oficial - soma_individuais
- **`juniors`**, **`plenos`**, **`seniors`** - ⭐ Contagens por nível

**Exemplo de Uso:**
```sql
-- Análise de composição
SELECT 
    nome_equipe,
    total_vendedores,
    juniors,
    plenos,
    seniors,
    media_meta_por_vendedor
FROM dim.VW_ANALISE_EQUIPE_VENDEDORES
ORDER BY total_vendedores DESC;

-- Equipes com gap de meta
SELECT 
    nome_equipe,
    meta_oficial_equipe,
    soma_metas_individuais,
    diferenca_metas
FROM dim.VW_ANALISE_EQUIPE_VENDEDORES
WHERE ABS(diferenca_metas) > 10000
ORDER BY ABS(diferenca_metas) DESC;
```

---

### 9️⃣ VW_EQUIPES_ATIVAS

**Nome Completo:** `dim.VW_EQUIPES_ATIVAS`  
**Script:** `09_vw_equipes_ativas.sql`  
**Tabela Base:** `dim.DIM_EQUIPE WHERE eh_ativa=1`  

**Propósito:**  
Listar equipes operacionais com métricas e classificações.

**Campos Principais:**
- `equipe_id`, `nome_equipe` - Identificação
- `tipo_equipe`, `categoria_equipe`, `regional` - Classificação
- `meta_mensal_equipe`, `meta_trimestral_equipe` - Metas
- `qtd_membros_atual`, `qtd_membros_ideal` - Composição
- **`vagas_em_aberto`** - ⭐ ideal - atual
- **`meta_mensal_per_capita`** - ⭐ meta / qtd_membros
- **`porte_equipe`** - ⭐ Grande/Média/Pequena/Vazia
- `lider_equipe_id`, `nome_lider` - Liderança
- **`meses_ativa`** - ⭐ Tempo desde criação

**Exemplo de Uso:**
```sql
-- Equipes com vagas abertas
SELECT 
    nome_equipe,
    regional,
    qtd_membros_atual,
    qtd_membros_ideal,
    vagas_em_aberto
FROM dim.VW_EQUIPES_ATIVAS
WHERE vagas_em_aberto > 0
ORDER BY vagas_em_aberto DESC;

-- Meta per capita por tipo
SELECT 
    tipo_equipe,
    AVG(meta_mensal_per_capita) AS meta_media_per_capita
FROM dim.VW_EQUIPES_ATIVAS
WHERE qtd_membros_atual > 0
GROUP BY tipo_equipe
ORDER BY meta_media_per_capita DESC;
```

---

### 🔟 VW_RANKING_EQUIPES_META

**Nome Completo:** `dim.VW_RANKING_EQUIPES_META`  
**Script:** `10_vw_ranking_equipes_meta.sql`  
**Tabela Base:** `dim.DIM_EQUIPE WHERE eh_ativa=1`  

**Propósito:**  
Ranking de equipes por meta mensal (geral e regional).

**Campos Principais:**
- **`ranking_geral`** - ⭐ ROW_NUMBER() geral
- **`ranking_regional`** - ⭐ ROW_NUMBER() por regional
- `equipe_id`, `nome_equipe` - Identificação
- `tipo_equipe`, `regional` - Classificação
- `meta_mensal_equipe` - Meta
- `qtd_membros_atual` - Composição
- **`meta_per_capita`** - ⭐ meta / membros
- **`faixa_meta`** - ⭐ Top/Alto/Médio/Baixo

**Exemplo de Uso:**
```sql
-- Top 10 equipes por meta
SELECT TOP 10
    ranking_geral,
    nome_equipe,
    regional,
    meta_mensal_equipe,
    faixa_meta
FROM dim.VW_RANKING_EQUIPES_META
ORDER BY ranking_geral;

-- Melhores de cada regional
SELECT *
FROM dim.VW_RANKING_EQUIPES_META
WHERE ranking_regional = 1
ORDER BY meta_mensal_equipe DESC;
```

---

### 1️⃣1️⃣ VW_ANALISE_REGIONAL_EQUIPES

**Nome Completo:** `dim.VW_ANALISE_REGIONAL_EQUIPES`  
**Script:** `11_vw_analise_regional_equipes.sql`  
**Tabela Base:** `dim.DIM_EQUIPE WHERE eh_ativa=1`  

**Propósito:**  
Agregação de equipes por regional para visão executiva.

**Campos Principais:**
- `regional` - Agrupamento
- **`total_equipes`** - ⭐ COUNT de equipes
- **`total_vendedores`** - ⭐ SUM de vendedores
- **`meta_mensal_regional`** - ⭐ SUM de metas
- **`meta_media_por_equipe`** - ⭐ AVG de meta
- **`menor_meta`**, **`maior_meta`** - ⭐ MIN/MAX
- **`meta_per_capita_regional`** - ⭐ Total meta / total vendedores
- **`equipes_diretas`**, **`equipes_inside`**, **`equipes_key_accounts`**, **`equipes_ecommerce`** - ⭐ Contagens por tipo

**Exemplo de Uso:**
```sql
-- Visão executiva por regional
SELECT 
    regional,
    total_equipes,
    total_vendedores,
    meta_mensal_regional,
    meta_per_capita_regional
FROM dim.VW_ANALISE_REGIONAL_EQUIPES
ORDER BY meta_mensal_regional DESC;

-- Distribuição de tipos de equipe por regional
SELECT 
    regional,
    equipes_diretas,
    equipes_inside,
    equipes_key_accounts,
    equipes_ecommerce
FROM dim.VW_ANALISE_REGIONAL_EQUIPES;
```

---

## 📊 VIEWS MESTRES (FACTS)

### 4️⃣ MASTER VIEWS

**Script:** `04_master_views.sql`  
**Contém:** 2 views principais

#### VW_VENDAS_COMPLETA

**Nome Completo:** `fact.VW_VENDAS_COMPLETA`  
**Base:** `FACT_VENDAS + todas dimensões`  

**Propósito:**  
Eliminar necessidade de JOINs repetitivos em análises de vendas.

**Campos Principais:**
- Todos campos de FACT_VENDAS
- Todos campos de negócio de todas dimensões relacionadas
- **Campos Calculados:**
  - `lucro_bruto` = valor_liquido - custo_total
  - `margem_percentual` = lucro / liquido * 100
  - `preco_medio_unitario` = liquido / quantidade
- **Flags Derivadas:**
  - `teve_devolucao` = quantidade_devolvida > 0
  - `eh_venda_direta` = vendedor_id IS NULL

**Exemplo de Uso:**
```sql
-- Análise completa sem JOINs
SELECT 
    categoria,
    nome_mes,
    COUNT(*) AS vendas,
    SUM(valor_total_liquido) AS receita,
    AVG(margem_percentual) AS margem_media
FROM fact.VW_VENDAS_COMPLETA
WHERE ano = 2024
GROUP BY categoria, nome_mes, mes
ORDER BY categoria, mes;
```

---

#### VW_METAS_COMPLETA

**Nome Completo:** `fact.VW_METAS_COMPLETA`  
**Base:** `FACT_METAS + DIM_VENDEDOR + DIM_EQUIPE + DIM_DATA`  

**Propósito:**  
Análise de performance vs metas com contexto completo.

**Campos Principais:**
- Todos campos de FACT_METAS
- Campos de DIM_VENDEDOR (nome, cargo, equipe)
- Campos de DIM_EQUIPE (tipo_equipe, regional)
- Campos de DIM_DATA (ano, mês, nome_mes)
- **Campo Calculado:**
  - `faixa_performance` = Classificação textual do atingimento
    - Excepcional (120%+)
    - Atingiu (100-120%)
    - Próximo (80-100%)
    - Abaixo (50-80%)
    - Crítico (<50%)

**Exemplo de Uso:**
```sql
-- Atingimento por equipe
SELECT 
    nome_equipe,
    COUNT(*) AS total_vendedores,
    AVG(percentual_atingido) AS perc_medio,
    SUM(CASE WHEN meta_batida = 1 THEN 1 ELSE 0 END) AS bateram_meta
FROM fact.VW_METAS_COMPLETA
WHERE ano = 2024 AND mes = 12
GROUP BY nome_equipe
ORDER BY perc_medio DESC;
```

---

## ⚠️ Boas Práticas

### ✅ Fazer

- ✅ Usar views para simplificar queries complexas
- ✅ Incluir apenas registros ativos (`WHERE eh_ativo=1`)
- ✅ Adicionar campos calculados úteis (margem, percentuais)
- ✅ Documentar propósito e casos de uso
- ✅ Nomear com prefixo `VW_`
- ✅ Usar INNER JOIN quando possível (performance)
- ✅ Incluir campos de todas dimensões relevantes nas views mestres

### ❌ Evitar

- ❌ Views aninhadas (view que usa outra view)
- ❌ Lógica de negócio complexa em views
- ❌ Views muito genéricas (`SELECT * FROM...`)
- ❌ Joins desnecessários
- ❌ Views sem filtros (retornar todos os registros sem critério)
- ❌ Campos calculados muito custosos (subqueries correlacionadas)

---

## 🔄 Dependências entre Views

```
Nível 1 (Independentes):
├─ VW_CALENDARIO_COMPLETO
├─ VW_PRODUTOS_ATIVOS
├─ VW_HIERARQUIA_GEOGRAFICA
├─ VW_DESCONTOS_ATIVOS
└─ VW_EQUIPES_ATIVAS

Nível 2 (Dependem de outras tabelas):
├─ VW_VENDEDORES_ATIVOS (→ DIM_EQUIPE)
├─ VW_HIERARQUIA_VENDEDORES (→ self-join)
├─ VW_ANALISE_EQUIPE_VENDEDORES (→ DIM_EQUIPE + DIM_VENDEDOR)
├─ VW_RANKING_EQUIPES_META (→ DIM_EQUIPE)
└─ VW_ANALISE_REGIONAL_EQUIPES (→ DIM_EQUIPE)

Nível 3 (Views mestres - dependem de tudo):
├─ VW_VENDAS_COMPLETA (→ FACT + todas dimensões)
└─ VW_METAS_COMPLETA (→ FACT_METAS + dimensões)
```

**Ordem de Criação Recomendada:** Seguir ordem numérica dos arquivos (01 → 11)

---

## 📈 Métricas das Views

| View | Registros | Atualização | Performance |
|------|-----------|-------------|-------------|
| VW_CALENDARIO_COMPLETO | ~3.650 | Estática | ⚡ Rápida |
| VW_PRODUTOS_ATIVOS | 100-10K | ETL Diário | ⚡ Rápida |
| VW_HIERARQUIA_GEOGRAFICA | 100-5K | Rara | ⚡ Rápida |
| VW_DESCONTOS_ATIVOS | 10-100 | Dinâmica | ⚡ Rápida |
| VW_VENDEDORES_ATIVOS | 50-1K | ETL Diário | ⚡ Rápida |
| VW_HIERARQUIA_VENDEDORES | 50-1K | ETL Diário | ⚡ Rápida |
| VW_ANALISE_EQUIPE_VENDEDORES | 10-100 | Dinâmica | 🔶 Média |
| VW_EQUIPES_ATIVAS | 10-100 | ETL Semanal | ⚡ Rápida |
| VW_RANKING_EQUIPES_META | 10-100 | Dinâmica | ⚡ Rápida |
| VW_ANALISE_REGIONAL