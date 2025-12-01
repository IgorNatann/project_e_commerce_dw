# 🏢 Data Warehouse E-commerce

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%2B-red)](https://www.microsoft.com/sql-server)
[![Python](https://img.shields.io/badge/Python-3.9%2B-blue)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Data Warehouse dimensional para análise de e-commerce, incluindo vendas, descontos, metas de vendedores e gestão de estoque multi-warehouse.

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Arquitetura](#arquitetura)
- [Tecnologias](#tecnologias)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Instalação](#instalação)
- [Uso](#uso)
- [Modelo Dimensional](#modelo-dimensional)
- [Queries de Exemplo](#queries-de-exemplo)
- [Dashboards](#dashboards)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

## 🎯 Sobre o Projeto

Este Data Warehouse foi desenvolvido seguindo a **metodologia Kimball** (modelagem dimensional) para análise de um e-commerce fictício. O projeto suporta análises de:

- 📊 **Vendas**: Análise de receita, ticket médio, sazonalidade
- 👥 **Vendedores**: Performance vs. metas, ranking de equipes
- 🏷️ **Descontos**: ROI de campanhas, impacto na margem
- 📦 **Estoque**: Giro por warehouse, produtos parados, transferências

### Características Principais

- ✅ **5 Tabelas Fato** e **8 Dimensões**
- ✅ Suporta múltiplos warehouses (centros de distribuição)
- ✅ Rastreamento de descontos em múltiplos níveis
- ✅ Snapshots diários de estoque
- ✅ Hierarquias temporais completas
- ✅ ~100.000 vendas de dados sintéticos

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────┐
│          CAMADA DE APRESENTAÇÃO             │
│   Metabase / Power BI / Grafana            │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│       DATA WAREHOUSE (SQL Server)           │
│  ┌──────────────────────────────────────┐  │
│  │   DIMENSÕES (8)                      │  │
│  │  • DIM_DATA                          │  │
│  │  • DIM_CLIENTE                       │  │
│  │  • DIM_PRODUTO                       │  │
│  │  • DIM_REGIAO                        │  │
│  │  • DIM_EQUIPE                        │  │
│  │  • DIM_VENDEDOR                      │  │
│  │  • DIM_DESCONTO                      │  │
│  │  • DIM_WAREHOUSE                     │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │   FATOS (5)                          │  │
│  │  • FACT_VENDAS                       │  │
│  │  • FACT_METAS                        │  │
│  │  • FACT_DESCONTOS                    │  │
│  │  • FACT_MOVIMENTACOES                │  │
│  │  • FACT_ESTOQUE_DIARIO               │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## 🛠️ Tecnologias

- **Banco de Dados**: SQL Server 2019+
- **ETL/Geração de Dados**: Python 3.9+
- **Bibliotecas Python**:
  - `pandas`: Manipulação de dados
  - `sqlalchemy`: Conexão com SQL Server
  - `faker`: Geração de dados sintéticos
  - `python-dotenv`: Gerenciamento de variáveis de ambiente
- **Visualização**: Metabase (opcional)
- **Versionamento**: Git

## 📂 Estrutura do Projeto

```
dw-ecommerce/
├── sql/                 # Scripts SQL organizados por fase
│   ├── 01_setup/
│   ├── 02_ddl/
│   ├── 03_dml/
│   ├── 04_views/
│   └── 06_queries/
├── python/              # Scripts Python para ETL e geração de dados
├── docs/                # Documentação técnica
├── dashboards/          # Configurações de dashboards
└── tests/               # Testes de qualidade de dados
```

## 🚀 Instalação

### Pré-requisitos

- SQL Server 2019+ instalado
- Python 3.9+ instalado
- Git instalado

### Passo 1: Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/dw-ecommerce.git
cd dw-ecommerce
```

### Passo 2: Configurar Ambiente Python

```bash
# Criar ambiente virtual
python -m venv venv

# Ativar ambiente virtual
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Instalar dependências
pip install -r python/requirements.txt
```

### Passo 3: Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de exemplo
cp python/.env.example python/.env

# Editar .env com suas credenciais
# DB_SERVER=localhost
# DB_NAME=DW_ECOMMERCE
# DB_USER=seu_usuario
# DB_PASSWORD=sua_senha
```

### Passo 4: Criar Database e Estrutura

```bash
# Executar scripts SQL na ordem
# No VS Code com extensão SQL Server:
# Abrir sql/01_setup/01_create_database.sql
# Executar (Ctrl+Shift+E)

# Ou via linha de comando:
sqlcmd -S localhost -i sql/01_setup/01_create_database.sql
sqlcmd -S localhost -d DW_ECOMMERCE -i sql/02_ddl/dimensions/01_dim_data.sql
# ... repetir para todos os arquivos DDL
```

### Passo 5: Gerar Dados Sintéticos

```bash
python python/data_generation/generate_clientes.py
python python/data_generation/generate_produtos.py
python python/data_generation/generate_vendas.py
# ... etc
```

## 💻 Uso

### Executar Queries de Análise

```sql
-- Vendas por mês (2024)
USE DW_ECOMMERCE;
GO

SELECT 
    d.periodo_mes,
    SUM(v.valor_total_liquido) as receita_total,
    COUNT(DISTINCT v.venda_id) as total_vendas,
    AVG(v.valor_total_liquido) as ticket_medio
FROM fact.FACT_VENDAS v
INNER JOIN dim.DIM_DATA d ON v.data_id = d.data_id
WHERE d.ano = 2024
GROUP BY d.periodo_mes
ORDER BY d.periodo_mes;
```

Ver mais exemplos em: [`sql/06_queries/`](sql/06_queries/)

## 📊 Modelo Dimensional

### Star Schema

![Star Schema](docs/modelagem/diagrams/star_schema.png)

### Dimensões

| Dimensão | Descrição | Registros |
|----------|-----------|-----------|
| DIM_DATA | Hierarquia temporal (2020-2025) | ~2.191 |
| DIM_CLIENTE | Clientes do e-commerce | ~10.000 |
| DIM_PRODUTO | Catálogo de produtos | ~500 |
| DIM_REGIAO | Geografia (país, estado, cidade) | ~100 |
| DIM_EQUIPE | Equipes de vendedores | ~10 |
| DIM_VENDEDOR | Vendedores | ~50 |
| DIM_DESCONTO | Cupons e campanhas | ~100 |
| DIM_WAREHOUSE | Centros de distribuição | ~5 |

### Tabelas Fato

| Fato | Granularidade | Registros |
|------|---------------|-----------|
| FACT_VENDAS | 1 item vendido | ~100.000 |
| FACT_METAS | 1 meta mensal por vendedor | ~600 |
| FACT_DESCONTOS | 1 desconto aplicado | ~30.000 |
| FACT_MOVIMENTACOES | 1 movimentação de estoque | ~200.000 |
| FACT_ESTOQUE_DIARIO | 1 snapshot diário por produto/warehouse | ~90.000 |

### Decisões de Design

- **Granularidade FACT_VENDAS**: 1 linha = 1 item vendido em 1 pedido
- **SCD Type**: Type 1 (sobrescrever) para todas dimensões
- **Transferências**: 2 linhas (saída + entrada) em FACT_MOVIMENTACOES
- **Snapshots**: Métricas semi-aditivas (não somar no tempo)

Ver documentação completa: [`docs/modelagem/`](docs/modelagem/)

## 🔍 Queries de Exemplo

### Top 10 Produtos Mais Vendidos

```sql
SELECT TOP 10
    p.nome_produto,
    p.categoria,
    SUM(v.quantidade_vendida) as total_unidades,
    SUM(v.valor_total_liquido) as receita_total
FROM fact.FACT_VENDAS v
INNER JOIN dim.DIM_PRODUTO p ON v.produto_id = p.produto_id
GROUP BY p.nome_produto, p.categoria
ORDER BY receita_total DESC;
```

### Performance Vendedor vs Meta

```sql
SELECT 
    vend.nome_vendedor,
    eq.nome_equipe,
    SUM(m.valor_meta) as meta_total,
    SUM(v.valor_total_liquido) as vendas_realizadas,
    CAST(SUM(v.valor_total_liquido) / NULLIF(SUM(m.valor_meta), 0) * 100 AS DECIMAL(5,2)) as perc_atingido
FROM fact.FACT_METAS m
INNER JOIN dim.DIM_VENDEDOR vend ON m.vendedor_id = vend.vendedor_id
INNER JOIN dim.DIM_EQUIPE eq ON vend.equipe_id = eq.equipe_id
LEFT JOIN fact.FACT_VENDAS v ON vend.vendedor_id = v.vendedor_id
GROUP BY vend.nome_vendedor, eq.nome_equipe
ORDER BY perc_atingido DESC;
```

Mais queries: [`sql/06_queries/`](sql/06_queries/)

## 📈 Dashboards

### KPIs Principais

- **Receita Total**: R$ XX.XXX.XXX
- **Ticket Médio**: R$ XXX
- **Total de Vendas**: XXX.XXX
- **Taxa de Conversão**: XX%
- **Produtos com Estoque Baixo**: XX

Ver configurações: [`dashboards/`](dashboards/)

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Distribuído sob a licença MIT. Veja `LICENSE` para mais informações.

## 👤 Autor

**Seu Nome**
- GitHub: [@seu-usuario](https://github.com/seu-usuario)
- LinkedIn: [Seu Nome](https://linkedin.com/in/seu-perfil)

## 🙏 Agradecimentos

- Metodologia Kimball para modelagem dimensional
- Comunidade SQL Server
- [Faker](https://faker.readthedocs.io/) para geração de dados sintéticos

---

⭐ **Se este projeto te ajudou, considere dar uma estrela!** ⭐