# 🏪 Data Warehouse E-commerce

> Modelo dimensional completo para análise de vendas, desempenho de vendedores e campanhas de desconto

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019+-CC2927?style=flat&logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![Star Schema](https://img.shields.io/badge/Model-Star%20Schema-blue)](https://en.wikipedia.org/wiki/Star_schema)
[![Kimball](https://img.shields.io/badge/Method-Kimball-green)](https://www.kimballgroup.com/)

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Arquitetura](#arquitetura)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Quick Start](#quick-start)
- [Documentação Completa](#documentação-completa)
- [Análises Suportadas](#análises-suportadas)
- [Roadmap](#roadmap)

---

## 🎯 Sobre o Projeto

Este Data Warehouse foi desenvolvido seguindo a **metodologia Kimball** para análise de dados de e-commerce. O modelo suporta análises complexas de vendas, performance de equipes, metas e efetividade de campanhas de desconto.

### ✨ Características Principais

- **7 Dimensões** modeladas com hierarquias completas
- **3 Tabelas Fato** para diferentes processos de negócio
- **Star Schema** otimizado para performance analítica
- **10+ Views** auxiliares para facilitar consultas
- **Dados de exemplo** para testes e validação
- **Documentação completa** inline e em markdown

### 🎓 Propósito Educacional

Este projeto serve como:
- **Referência** de modelagem dimensional
- **Template** para projetos similares
- **Material didático** com comentários explicativos
- **Boas práticas** de SQL e DW design

---

## 🏗️ Arquitetura

### Modelo Dimensional

```
┌─────────────────────────────────────────────────────────────┐
│                      STAR SCHEMA                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│     DIM_DATA          DIM_EQUIPE         DIM_DESCONTO      │
│         │                  │                    │          │
│         │                  │                    │          │
│         ├──────────┬───────┼────────┬───────────┤          │
│         │          │       │        │           │          │
│    FACT_VENDAS  ──────  DIM_VENDEDOR  ──  FACT_DESCONTOS  │
│         │          │                 │                     │
│         ├──────────┼─────────────────┘                     │
│         │          │                                       │
│   DIM_CLIENTE  DIM_PRODUTO  DIM_REGIAO                    │
│                                                             │
│                   FACT_METAS ── DIM_VENDEDOR               │
│                        │                                    │
│                    DIM_DATA                                 │
└─────────────────────────────────────────────────────────────┘
```

### Principais Componentes

#### 📐 Dimensões (7)
1. **DIM_DATA** - Hierarquia temporal completa
2. **DIM_CLIENTE** - Segmentação e localização
3. **DIM_PRODUTO** - Categorias e fornecedores
4. **DIM_REGIAO** - Hierarquia geográfica
5. **DIM_VENDEDOR** - Força de vendas
6. **DIM_EQUIPE** - Times comerciais
7. **DIM_DESCONTO** - Campanhas e cupons

#### 📊 Tabelas Fato (3)
1. **FACT_VENDAS** - Transações de venda (transacional)
2. **FACT_METAS** - Metas vs realizado (periódica)
3. **FACT_DESCONTOS** - Descontos aplicados (eventos)

---

## 📁 Estrutura do Repositório

```
PROJECT_E-COMMERCE_DW/
│
├── 📄 README.md                          # Este arquivo
├── 📄 .gitignore
│
├── 📂 docs/                              # Documentação detalhada
│   ├── 📂 decisoes/                      # Decisões de design
│   ├── 📂 modelagem/                     # Decisões de Modelo de dados
│   └── 📂 queries/                       # Exemplos de análises
│
├── 📂 sql/                               # Scripts SQL
│   ├── 📂 01_setup/                      # Criação inicial
│   │   ├── 01_create_database.sql
│   │   ├── 02_create_schemas.sql
│   │   └── 03_configure_database.sql
│   │
│   ├── 📂 02_ddl/                        # Definição de estruturas
│   │   ├── 📂 dimensions/                # Dimensões
│   │   ├── 📂 facts/                     # Tabelas fato
│   │   └── 📂 indexes/                   # Índices
│   │
│   ├── 📂 04_views/                      # Views auxiliares
│   │   ├── 01_vw_calendario_completo.sql
│   │   ├── 02_vw_produtos_ativos.sql
│   │   ├── 03_vw_hierarquia_geografica.sql
│   │   ├── 04_master_views.sql
│   │   ├── 05_vw_descontos_ativos.sql
│   │   ├── 06_vw_vendedores_ativos.sql
│   │   ├── 07_vw_hierarquia_vendedores.sql
│   │   ├── 08_dw_analise_equipe_vendedores.sql
│   │   ├── 09_vw_equipes_ativas.sql
│   │   ├── 10_vw_ranking_equipes_meta.sql
│   │   └── 11_vw_analise_regional_equipes.sql
│   │
│   ├── 📂 05_procedures/                 # Stored procedures (futuro)
│   ├── 📂 06_queries/                    # Queries analíticas
│   └── 📂 99_maintenance/                # Manutenção
│
├── 📂 dashboards/                        # Dashboards e visualizações
├── 📂 data/                              # Dados de exemplo (CSV)
├── 📂 notebooks/                         # Jupyter notebooks
├── 📂 python/                            # Scripts Python (ETL)
├── 📂 scripts/                           # Scripts auxiliares
└── 📂 tests/                             # Testes de validação
```

---

## 🚀 Quick Start

### Pré-requisitos

- SQL Server 2019 ou superior
- SQL Server Management Studio (SSMS) ou Azure Data Studio
- Permissões para criar databases

### Instalação

#### 1️⃣ Clone o repositório

```bash
git clone https://github.com/seu-usuario/project-e-commerce-dw.git
cd project-e-commerce-dw
```

#### 2️⃣ Execute os scripts na ordem

```sql
-- 1. Setup inicial
USE master;
GO
:r sql/01_setup/01_create_database.sql
:r sql/01_setup/02_create_schemas.sql
:r sql/01_setup/03_configure_database.sql

-- 2. Criação das Dimensões (DDL)
USE DW_ECOMMERCE;
GO
:r sql/02_ddl/dimensions/02_dim_data.sql
:r sql/02_ddl/dimensions/03_dim_cliente.sql
:r sql/02_ddl/dimensions/03_dim_produto.sql
:r sql/02_ddl/dimensions/04_dim_regiao.sql
:r sql/02_ddl/dimensions/05_dim_equipe.sql
:r sql/02_ddl/dimensions/06_dim_vendedor.sql
:r sql/02_ddl/dimensions/07_dim_desconto.sql

-- 3. Criação das Facts (DDL)
:r sql/02_ddl/facts/07_fact_vendas.sql
:r sql/02_ddl/facts/08_fact_metas.sql
:r sql/02_ddl/facts/09_fact_descontos.sql

-- 4. Views auxiliares
:r sql/04_views/01_vw_calendario_completo.sql
:r sql/04_views/02_vw_produtos_ativos.sql
-- ... demais views
```

#### 3️⃣ Validar instalação

```sql
-- Verificar tabelas criadas
SELECT 
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS table_name,
    type_desc
FROM sys.objects
WHERE type IN ('U', 'V')
ORDER BY schema_name, type_desc, name;

-- Contar registros
SELECT 'DIM_DATA' AS tabela, COUNT(*) AS registros FROM dim.DIM_DATA
UNION ALL
SELECT 'DIM_CLIENTE', COUNT(*) FROM dim.DIM_CLIENTE
UNION ALL
SELECT 'DIM_PRODUTO', COUNT(*) FROM dim.DIM_PRODUTO
UNION ALL
SELECT 'FACT_VENDAS', COUNT(*) FROM fact.FACT_VENDAS;
```

### 🎬 Primeira Query

```sql
-- Top 5 produtos mais vendidos no último mês
SELECT TOP 5
    p.nome_produto,
    p.categoria,
    SUM(fv.quantidade_vendida) AS qtd_vendida,
    SUM(fv.valor_total_liquido) AS receita_total
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.data_completa >= DATEADD(MONTH, -1, GETDATE())
GROUP BY p.nome_produto, p.categoria
ORDER BY receita_total DESC;
```

---

## 📚 Documentação Completa

### 📖 Guias Principais

- **[Visão Geral da Modelagem](docs/modelagem/01_visao_geral.md)** - Entenda a arquitetura
- **[Dimensões Detalhadas](docs/modelagem/02_dimensoes.md)** - Todas as dimensões explicadas
- **[Tabelas Fato](docs/modelagem/03_fatos.md)** - Granularidade e métricas
- **[Relacionamentos](docs/modelagem/04_relacionamentos.md)** - Mapa de FKs
- **[Decisões de Design](docs/decisoes/01_decisoes_modelagem.md)** - Por que fizemos assim
- **[Queries e Análises](docs/queries/README.md)** - Exemplos práticos

### 🛠️ Guias Técnicos

- **[Como Executar Scripts](sql/README.md)** - Ordem e dependências
- **[Views Auxiliares](sql/04_views/README.md)** - Catálogo de views
- **[Dicionário de Dados](docs/modelagem/05_dicionario_dados.md)** - Todos os campos

---

## 📊 Análises Suportadas

### 🎯 Vendas e Performance

- ✅ Vendas por período (dia, mês, trimestre, ano)
- ✅ Vendas por região e hierarquia geográfica
- ✅ Vendas por categoria de produto
- ✅ Análise de margem e lucratividade
- ✅ Taxa de devolução por produto/fornecedor
- ✅ Ticket médio por segmento de cliente
- ✅ Sazonalidade e tendências

### 👥 Vendedores e Equipes

- ✅ Performance individual de vendedores
- ✅ Atingimento de metas (% realizado vs meta)
- ✅ Ranking de vendedores por período
- ✅ Comparação entre equipes e regionais
- ✅ Análise de comissionamento
- ✅ Vendas com vs sem vendedor (e-commerce direto)

### 🎟️ Descontos e Campanhas

- ✅ ROI de cupons e campanhas
- ✅ Impacto de descontos na margem
- ✅ Efetividade por tipo de desconto
- ✅ Produtos mais descontados
- ✅ Ticket médio com/sem desconto
- ✅ Análise de múltiplos descontos por pedido

---

## 🗺️ Roadmap

### ✅ Fase 1 - Concluída
- [x] Modelo dimensional base (7 dimensões, 3 facts)
- [x] Dados de exemplo
- [x] Views auxiliares
- [x] Documentação inline

### 🚧 Fase 2 - Em Progresso
- [ ] Documentação completa em Markdown
- [ ] Queries analíticas prontas
- [ ] Diagramas visuais (ER Diagram)
- [ ] Testes de integridade

### 📋 Fase 3 - Planejada
- [ ] Scripts Python para ETL
- [ ] Dashboards em Power BI
- [ ] Procedures para carga incremental
- [ ] Data quality checks
- [ ] Aggregate tables

### 🔮 Fase 4 - Futuro
- [ ] DIM_CANAL (multicanal)
- [ ] FACT_ESTOQUE
- [ ] FACT_PAGAMENTOS
- [ ] SCD Type 2 para dimensões críticas
- [ ] Machine Learning (previsões)

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Faça fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## 📝 Licença

Este projeto é open source e está disponível sob a [MIT License](LICENSE).

---

## 👤 Autor

**Seu Nome**
- GitHub: [@IgorNatann](https://github.com/IgorNatann)
- LinkedIn: [@igornatan](https://www.linkedin.com/in/igornatan)

---

## 🙏 Agradecimentos

- Metodologia Kimball Group
- Comunidade SQL Server
- Contribuidores do projeto

---

## 📞 Suporte

- 📖 [Documentação Completa](docs/)
- 🐛 [Reportar Bug](https://github.com/seu-usuario/project-e-commerce-dw/issues)
- 💡 [Solicitar Feature](https://github.com/seu-usuario/project-e-commerce-dw/issues)
- 💬 [Discussões](https://github.com/seu-usuario/project-e-commerce-dw/discussions)

---

<div align="center">

**[⬆ Voltar ao topo](#-data-warehouse-e-commerce)**

Feito com ❤️ para a comunidade de Data Engineering

</div>
