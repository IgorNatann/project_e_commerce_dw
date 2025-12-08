# 05_views - Camada de Visualização

## 📋 Visão Geral

Este diretório contém as **views** auxiliares do Data Warehouse, que simplificam queries complexas e padronizam o acesso aos dados dimensionais.

## 🎯 Propósito das Views

As views servem para:
- ✅ Simplificar queries frequentes
- ✅ Incluir campos calculados reutilizáveis
- ✅ Filtrar apenas registros ativos (eh_ativo=1)
- ✅ Padronizar acesso aos dados entre equipes
- ✅ Facilitar drill-down e hierarquias

## 📁 Estrutura de Arquivos

| Arquivo | Descrição | Dependência |
|---------|-----------|-------------|
| `01_vw_calendario_completo.sql` | View temporal com campos calculados | DIM_DATA |
| `02_vw_produtos_ativos.sql` | Produtos ativos com margem/markup | DIM_PRODUTO |
| `03_vw_hierarquia_geografica.sql` | Hierarquia geográfica completa | DIM_REGIAO |
| `_master_views.sql` | Executa todas as views em ordem | Todas acima |

## 🚀 Como Executar

### Opção 1: Todas as views de uma vez
```bash
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i _master_views.sql
```

### Opção 2: View individual
```bash
sqlcmd -S SEU_SERVIDOR -d DW_ECOMMERCE -i 01_vw_calendario_completo.sql
```

### Opção 3: Via SSMS
1. Abra o script desejado no SSMS
2. Conecte ao banco **DW_ECOMMERCE**
3. Execute (F5)

## 📊 Views Disponíveis

### 1️⃣ VW_CALENDARIO_COMPLETO
**Schema:** `dim`  
**Tabela Base:** `DIM_DATA`  
**Campos Principais:**
- Hierarquia temporal completa (ano > trimestre > mês > dia)
- `eh_dia_util` (calculado: NOT (fim_semana OR feriado))
- `periodo_desc` (formatação para relatórios)
- `semana_ano`, `dia_ano`

**Exemplo de Uso:**
```sql
-- Vendas apenas em dias úteis de 2024
SELECT 
    vc.nome_mes,
    COUNT(*) AS total_vendas
FROM fact.FACT_VENDAS fv
JOIN dim.VW_CALENDARIO_COMPLETO vc ON fv.data_id = vc.data_id
WHERE vc.ano = 2024 AND vc.eh_dia_util = 1
GROUP BY vc.nome_mes;
```

---

### 2️⃣ VW_PRODUTOS_ATIVOS
**Schema:** `dim`  
**Tabela Base:** `DIM_PRODUTO`  
**Campos Principais:**
- Apenas produtos ativos (`eh_ativo=1`)
- `margem_sugerida` (% lucro sobre preço)
- `markup_percentual` (% acima do custo)
- `hierarquia_completa` (categoria > subcategoria > produto)
- `faixa_preco` (classificação: Premium, Alto, Médio, Baixo)

**Exemplo de Uso:**
```sql
-- Top 10 produtos com maior margem
SELECT TOP 10
    nome_produto,
    categoria,
    preco_sugerido,
    margem_sugerida
FROM dim.VW_PRODUTOS_ATIVOS
ORDER BY margem_sugerida DESC;
```

---

### 3️⃣ VW_HIERARQUIA_GEOGRAFICA
**Schema:** `dim`  
**Tabela Base:** `DIM_REGIAO`  
**Campos Principais:**
- Hierarquia geográfica (país > região > estado > cidade)
- `classificacao_populacional` (Metrópole, Grande, Médio, Pequeno)
- `classificacao_idh` (Muito Alto, Alto, Médio, Baixo)
- `eh_capital` (flag booleana)
- Dados demográficos e econômicos

**Exemplo de Uso:**
```sql
-- Vendas por região do Brasil
SELECT 
    vhg.regiao_pais,
    COUNT(DISTINCT fv.venda_id) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.VW_HIERARQUIA_GEOGRAFICA vhg ON fv.regiao_id = vhg.regiao_id
GROUP BY vhg.regiao_pais
ORDER BY receita DESC;
```

## ⚠️ Boas Práticas

### ✅ Fazer
- Usar views para simplificar queries complexas
- Incluir apenas registros ativos (WHERE eh_ativo=1)
- Adicionar campos calculados úteis
- Documentar propósito e casos de uso
- Nomear com prefixo `VW_`

### ❌ Evitar
- Views aninhadas (view que usa outra view)
- Lógica de negócio complexa em views
- Views muito genéricas (SELECT * FROM...)
- Joins desnecessários
- Views sem filtros (retornar todos os registros)

## 🔄 Versionamento Git

### Convenção de Commits
```bash
# Criação de nova view
git commit -m "feat(views): adiciona VW_CALENDARIO_COMPLETO"

# Alteração em view existente
git commit -m "refactor(views): adiciona campo eh_dia_util em VW_CALENDARIO_COMPLETO"

# Correção de bug
git commit -m "fix(views): corrige cálculo de margem_sugerida em VW_PRODUTOS_ATIVOS"
```

## 📝 Próximos Passos

- [ ] Criar views para tabelas FACT (vendas, metas, descontos)
- [ ] Adicionar views de análise consolidada
- [ ] Documentar views de relatórios
- [ ] Criar views para dashboards específicos

## 📞 Suporte

Para dúvidas ou sugestões sobre as views:
- Documentação completa: [link interno]
- Slack: #dw-ecommerce
- Email: dw-team@empresa.com