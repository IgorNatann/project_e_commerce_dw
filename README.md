# Data Warehouse E-commerce

Modelo dimensional para analise de vendas, performance comercial e campanhas de desconto em SQL Server.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019+-CC2927?style=flat&logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![Model](https://img.shields.io/badge/Model-Star%20Schema-blue)](https://en.wikipedia.org/wiki/Star_schema)
[![Method](https://img.shields.io/badge/Method-Kimball-green)](https://www.kimballgroup.com/)

## Sobre o projeto

Este repositorio implementa um Data Warehouse com abordagem Kimball:

- 7 dimensoes (`dim`)
- 3 tabelas fato (`fact`)
- 10 views auxiliares + 1 script master em `sql/dw/04_views`
- dados de exemplo incluidos nos scripts DDL
- documentacao detalhada em `docs/`

## Escopo atual

### Dimensoes

1. `DIM_DATA`
2. `DIM_CLIENTE`
3. `DIM_PRODUTO`
4. `DIM_REGIAO`
5. `DIM_EQUIPE`
6. `DIM_VENDEDOR`
7. `DIM_DESCONTO`

### Fatos

1. `FACT_VENDAS`
2. `FACT_METAS`
3. `FACT_DESCONTOS`

## Estrutura real do repositorio

```text
project_e-commerce_dw/
|
|-- README.md
|-- .gitignore
|
|-- docs/
|   |-- decisoes/
|   |-- diagrams/
|   |-- modelagem/
|   `-- queries/
|
|-- sql/
|   |-- README.md
|   `-- dw/
|       |-- 01_setup/
|       |-- 02_ddl/
|       |   |-- dimensions/
|       |   `-- facts/
|       |-- 03_dml/
|       |-- 04_views/
|       |-- 05_procedures/
|       |-- 06_queries/
|       `-- 99_maintenance/
|
|-- data/
|   |-- raw/
|   `-- staging/
|
`-- python/
    |-- data_generation/
    `-- requirements.txt
```

## Quick start

### Pre-requisitos

- SQL Server 2019+
- SSMS ou Azure Data Studio
- permissao para criar database e objetos

### Ordem de execucao

```sql
-- 1) Setup
USE master;
GO
:r sql/dw/01_setup/01_create_database.sql
:r sql/dw/01_setup/02_create_schemas.sql
:r sql/dw/01_setup/03_configure_database.sql

-- 2) Dimensoes
USE DW_ECOMMERCE;
GO
:r sql/dw/02_ddl/dimensions/01_dim_data.sql
:r sql/dw/02_ddl/dimensions/02_dim_cliente.sql
:r sql/dw/02_ddl/dimensions/03_dim_produto.sql
:r sql/dw/02_ddl/dimensions/04_dim_regiao.sql
:r sql/dw/02_ddl/dimensions/05_dim_equipe.sql
:r sql/dw/02_ddl/dimensions/06_dim_vendedor.sql
:r sql/dw/02_ddl/dimensions/07_dim_desconto.sql

-- 3) Fatos
:r sql/dw/02_ddl/facts/01_fact_vendas.sql
:r sql/dw/02_ddl/facts/02_fact_metas.sql
:r sql/dw/02_ddl/facts/03_fact_descontos.sql

-- 4) Views auxiliares
:r sql/dw/04_views/04_master_views.sql

-- (opcional) Execucao individual
:r sql/dw/04_views/01_vw_calendario_completo.sql
:r sql/dw/04_views/02_vw_produtos_ativos.sql
:r sql/dw/04_views/03_vw_hierarquia_geografica.sql
:r sql/dw/04_views/05_vw_descontos_ativos.sql
:r sql/dw/04_views/06_vw_vendedores_ativos.sql
:r sql/dw/04_views/07_vw_hierarquia_vendedores.sql
:r sql/dw/04_views/08_dw_analise_equipe_vendedores.sql
:r sql/dw/04_views/09_vw_equipes_ativas.sql
:r sql/dw/04_views/10_vw_ranking_equipes_meta.sql
:r sql/dw/04_views/11_vw_analise_regional_equipes.sql
```

### Validacao minima

```sql
USE DW_ECOMMERCE;
GO

SELECT 'dim.DIM_DATA' AS objeto, COUNT(*) AS registros FROM dim.DIM_DATA
UNION ALL
SELECT 'dim.DIM_CLIENTE', COUNT(*) FROM dim.DIM_CLIENTE
UNION ALL
SELECT 'dim.DIM_PRODUTO', COUNT(*) FROM dim.DIM_PRODUTO
UNION ALL
SELECT 'fact.FACT_VENDAS', COUNT(*) FROM fact.FACT_VENDAS
UNION ALL
SELECT 'fact.FACT_METAS', COUNT(*) FROM fact.FACT_METAS
UNION ALL
SELECT 'fact.FACT_DESCONTOS', COUNT(*) FROM fact.FACT_DESCONTOS;
```

## Documentacao

- [PRD do produto](docs/produto/PRD.md)
- [Plano de execucao R1](docs/produto/PLANO_EXECUCAO_R1.md)
- [Visao geral da modelagem](docs/modelagem/01_visao_geral.md)
- [Dimensoes](docs/modelagem/02_dimensoes.md)
- [Fatos](docs/modelagem/03_fatos.md)
- [Relacionamentos](docs/modelagem/04_relacionamentos.md)
- [Dicionario de dados](docs/modelagem/05_dicionario_dados.md)
- [Decisoes de modelagem](docs/decisoes/01_decisoes_modelagem.md)
- [Queries de exemplo](docs/queries/README.md)
- [Guia SQL de execucao](sql/README.md)
- [Catalogo de views](sql/dw/04_views/README.md)

## Maturidade atual

Consolidado:

- modelagem dimensional base
- scripts de criacao/populacao
- constraints e indices principais
- views de apoio para analise
- documentacao tecnica extensa

Em evolucao:

- padronizacao final de documentacao operacional
- camada ETL em `python/`
- testes automatizados de integridade

## Proximos passos recomendados

1. Adicionar suite de validacao SQL automatizada (smoke tests + regressao de views).
2. Padronizar e revisar documentacao operacional de execucao.
3. Implementar pipeline ETL incremental (staging -> dim/fact).
4. Publicar dashboards e consultas analiticas prontas.

## Autor

Igor Natan

- GitHub: [@IgorNatann](https://github.com/IgorNatann)
- LinkedIn: [@igornatan](https://www.linkedin.com/in/igornatan)

## Licenca

Arquivo `LICENSE` ainda nao esta presente no repositorio.
