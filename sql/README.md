# 📜 Scripts SQL - Guia de Execução

> Ordem correta de execução dos scripts e suas dependências

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Ordem de Execução](#ordem-de-execução)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura de Pastas](#estrutura-de-pastas)
- [Guia Passo a Passo](#guia-passo-a-passo)
- [Validação](#validação)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Este diretório contém **todos os scripts SQL** necessários para criar e popular o Data Warehouse E-commerce. Os scripts estão organizados por fase e devem ser executados em ordem específica devido às dependências entre objetos.

### 📊 Estatísticas

- **8 scripts de setup/DDL principais**
- **10 views auxiliares + 1 script master**
- **~3.000 linhas de código SQL**
- **Tempo estimado de execução:** 5-10 minutos

---

## ⚡ Ordem de Execução

### Resumo Rápido

```
dw/01_setup -> dw/02_ddl (dimensions) -> dw/03_etl_control -> dw/02_ddl (facts) -> dw/04_views
```

### Detalhado

```
┌─────────────────────────────────────────────────────────────────┐
│ FASE 1: SETUP INICIAL                                           │
├─────────────────────────────────────────────────────────────────┤
│ 1. 01_create_database.sql        ← Cria database DW_ECOMMERCE  │
│ 2. 02_create_schemas.sql         ← Cria schemas (dim, fact)    │
│ 3. 03_configure_database.sql     ← Configurações e permissões  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ FASE 2: DIMENSÕES (DDL)                                         │
├─────────────────────────────────────────────────────────────────┤
│ 4. 01_dim_data.sql               ← Dimensão Tempo              │
│ 5. 02_dim_cliente.sql            ← Dimensão Cliente            │
│ 6. 03_dim_produto.sql            ← Dimensão Produto            │
│ 7. 04_dim_regiao.sql             ← Dimensão Região             │
│ 8. 05_dim_equipe.sql             ← Dimensão Equipe             │
│ 9. 06_dim_vendedor.sql           ← Dimensão Vendedor ⚠️        │
│ 10. 07_dim_desconto.sql          ← Dimensão Desconto           │
└─────────────────────────────────────────────────────────────────┘
   ⚠️ Nota: dim_vendedor tem FK para dim_equipe (dependência)

┌─────────────────────────────────────────────────────────────────┐
│ FASE 3: TABELAS FATO (DDL)                                      │
├─────────────────────────────────────────────────────────────────┤
│ 11. 01_fact_vendas.sql           ← Fact Vendas (principal)     │
│ 12. 02_fact_metas.sql            ← Fact Metas (periódica)      │
│ 13. 03_fact_descontos.sql        ← Fact Descontos (eventos)    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ FASE 4: VIEWS AUXILIARES                                        │
├─────────────────────────────────────────────────────────────────┤
│ 14. 01_vw_calendario_completo.sql                               │
│ 15. 02_vw_produtos_ativos.sql                                   │
│ 16. 03_vw_hierarquia_geografica.sql                             │
│ 17. 04_master_views.sql                                         │
│ 18. 05_vw_descontos_ativos.sql                                  │
│ 19. 06_vw_vendedores_ativos.sql                                 │
│ 20. 07_vw_hierarquia_vendedores.sql                             │
│ 21. 08_dw_analise_equipe_vendedores.sql                         │
│ 22. 09_vw_equipes_ativas.sql                                    │
│ 23. 10_vw_ranking_equipes_meta.sql                              │
│ 24. 11_vw_analise_regional_equipes.sql                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Pré-requisitos

### Software

- **SQL Server 2019+** (Express, Standard ou Enterprise)
- **SSMS** ou **Azure Data Studio**
- **Permissões:** `CREATE DATABASE`, `CREATE SCHEMA`, `CREATE TABLE`

### Configuração Recomendada

```sql
-- Verificar versão do SQL Server
SELECT @@VERSION;

-- Verificar permissões
SELECT 
    HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE DATABASE') AS can_create_database,
    HAS_PERMS_BY_NAME('master', 'DATABASE', 'ALTER') AS can_alter_database;

-- Configurar para modo batch
SET NOCOUNT ON;
GO
```

---

## 📁 Estrutura de Pastas

```
sql/
|
|-- README.md
|-- dw/                           # Scripts do Data Warehouse (estado atual)
|   |-- 01_setup/
|   |-- 02_ddl/
|   |   |-- dimensions/
|   |   `-- facts/
|   |-- 03_etl_control/
|   |   `-- 99_validation/
|   |-- 03_dml/
|   |-- 04_views/
|   |-- 05_procedures/
|   |-- 06_queries/
|   `-- 99_maintenance/
|
`-- oltp/                         # Em construcao (proxima camada)
```

---

## 🚀 Guia Passo a Passo

### Método 1: Execução Manual (SSMS)

#### **Passo 1: Setup Inicial**

```sql
-- Conectar ao SQL Server como sysadmin
-- Database: master

-- 1.1 Criar database
:r C:\path\to\sql\dw\01_setup\01_create_database.sql
GO

-- 1.2 Mudar contexto e criar schemas
USE DW_ECOMMERCE;
GO
:r C:\path\to\sql\dw\01_setup\02_create_schemas.sql
GO

-- 1.3 Configurar database
:r C:\path\to\sql\dw\01_setup\03_configure_database.sql
GO
```

#### **Passo 2: Criar Dimensões**

```sql
-- ⚠️ IMPORTANTE: Executar na ORDEM CORRETA
USE DW_ECOMMERCE;
GO

-- 2.1 Dimensões independentes (podem ser paralelas)
:r C:\path\to\sql\dw\02_ddl\dimensions\01_dim_data.sql
:r C:\path\to\sql\dw\02_ddl\dimensions\02_dim_cliente.sql
:r C:\path\to\sql\dw\02_ddl\dimensions\03_dim_produto.sql
:r C:\path\to\sql\dw\02_ddl\dimensions\04_dim_regiao.sql
:r C:\path\to\sql\dw\02_ddl\dimensions\07_dim_desconto.sql

-- 2.2 Dimensões com dependências (ORDEM OBRIGATÓRIA)
:r C:\path\to\sql\dw\02_ddl\dimensions\05_dim_equipe.sql    -- ANTES
:r C:\path\to\sql\dw\02_ddl\dimensions\06_dim_vendedor.sql  -- DEPOIS
```

> **💡 Dica:** Cada script imprime mensagens de progresso. Acompanhe!

#### **Passo 3: Criar Controle ETL**

```sql
USE DW_ECOMMERCE;
GO
:r C:\path\to\sql\dw\03_etl_control\01_create_schema_ctl.sql
:r C:\path\to\sql\dw\03_etl_control\02_create_etl_control.sql
:r C:\path\to\sql\dw\03_etl_control\03_create_audit_etl_tables.sql
:r C:\path\to\sql\dw\03_etl_control\04_seed_etl_control.sql
:r C:\path\to\sql\dw\03_etl_control\99_validation\01_checks.sql
```

#### **Passo 4: Criar Facts**

```sql
USE DW_ECOMMERCE;
GO

-- 3.1 Fact principal
:r C:\path\to\sql\dw\02_ddl\facts\01_fact_vendas.sql

-- 3.2 Facts secundárias
:r C:\path\to\sql\dw\02_ddl\facts\02_fact_metas.sql
:r C:\path\to\sql\dw\02_ddl\facts\03_fact_descontos.sql
```

#### **Passo 5: Criar Views**

```sql
USE DW_ECOMMERCE;
GO

-- Executar views na ordem (ou rodar script master)
:r C:\path\to\sql\dw\04_views\04_master_views.sql

-- Alternativa: executar individualmente
:r C:\path\to\sql\dw\04_views\01_vw_calendario_completo.sql
:r C:\path\to\sql\dw\04_views\02_vw_produtos_ativos.sql
-- ... demais views
```

---

### Método 2: Script Master (Automatizado)

Crie um arquivo `execute_all.sql`:

```sql
-- ============================================
-- SCRIPT MASTER - EXECUÇÃO COMPLETA
-- ============================================
-- Tempo estimado: 5-10 minutos
-- ============================================

PRINT '🚀 Iniciando criação do Data Warehouse E-commerce...';
PRINT '';

-- FASE 1: SETUP
PRINT '📦 FASE 1: Setup Inicial';
:r .\dw\01_setup\01_create_database.sql
:r .\dw\01_setup\02_create_schemas.sql
:r .\dw\01_setup\03_configure_database.sql

USE DW_ECOMMERCE;
GO

-- FASE 2: DIMENSÕES
PRINT '📐 FASE 2: Criando Dimensões';
:r .\dw\02_ddl\dimensions\01_dim_data.sql
:r .\dw\02_ddl\dimensions\02_dim_cliente.sql
:r .\dw\02_ddl\dimensions\03_dim_produto.sql
:r .\dw\02_ddl\dimensions\04_dim_regiao.sql
:r .\dw\02_ddl\dimensions\05_dim_equipe.sql
:r .\dw\02_ddl\dimensions\06_dim_vendedor.sql
:r .\dw\02_ddl\dimensions\07_dim_desconto.sql

-- FASE 3: CONTROLE ETL
PRINT 'FASE 3: Criando tabelas de controle/auditoria do ETL';
:r .\dw\03_etl_control\01_create_schema_ctl.sql
:r .\dw\03_etl_control\02_create_etl_control.sql
:r .\dw\03_etl_control\03_create_audit_etl_tables.sql
:r .\dw\03_etl_control\04_seed_etl_control.sql
:r .\dw\03_etl_control\99_validation\01_checks.sql

-- FASE 4: FACTS
PRINT 'FASE 4: Criando Tabelas Fato';
:r .\dw\02_ddl\facts\01_fact_vendas.sql
:r .\dw\02_ddl\facts\02_fact_metas.sql
:r .\dw\02_ddl\facts\03_fact_descontos.sql

-- FASE 5: VIEWS
PRINT 'FASE 5: Criando Views Auxiliares';
:r .\dw\04_views\04_master_views.sql

PRINT '';
PRINT '✅ Data Warehouse criado com sucesso!';
PRINT '📊 Execute queries de validação para confirmar.';
```

**Executar:**

```bash
sqlcmd -S localhost -E -i execute_all.sql
```

---

## ✅ Validação

### Script de Validação Completa

```sql
-- ============================================
-- SCRIPT DE VALIDAÇÃO - DW_ECOMMERCE
-- ============================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'VALIDAÇÃO DO DATA WAREHOUSE';
PRINT '========================================';
PRINT '';

-- 1. Verificar Database
PRINT '1. Database:';
SELECT 
    name AS database_name,
    state_desc,
    recovery_model_desc,
    compatibility_level
FROM sys.databases
WHERE name = 'DW_ECOMMERCE';
PRINT '';

-- 2. Verificar Schemas
PRINT '2. Schemas:';
SELECT name AS schema_name
FROM sys.schemas
WHERE name IN ('dim', 'fact', 'stg', 'audit', 'ctl')
ORDER BY name;
PRINT '';

-- 3. Verificar Dimensões
PRINT '3. Dimensões Criadas:';
SELECT 
    name AS dimension_name,
    OBJECT_SCHEMA_NAME(object_id) AS schema_name,
    create_date
FROM sys.tables
WHERE OBJECT_SCHEMA_NAME(object_id) = 'dim'
ORDER BY name;
PRINT '';

-- 4. Verificar Facts
PRINT '4. Facts Criadas:';
SELECT 
    name AS fact_name,
    OBJECT_SCHEMA_NAME(object_id) AS schema_name,
    create_date
FROM sys.tables
WHERE OBJECT_SCHEMA_NAME(object_id) = 'fact'
ORDER BY name;
PRINT '';

-- 5. Verificar Views
PRINT '5. Views Criadas:';
SELECT 
    name AS view_name,
    OBJECT_SCHEMA_NAME(object_id) AS schema_name
FROM sys.views
WHERE OBJECT_SCHEMA_NAME(object_id) IN ('dim', 'fact')
ORDER BY schema_name, name;
PRINT '';

-- 6. Contar Registros
PRINT '6. Contagem de Registros:';
SELECT 'DIM_DATA' AS tabela, COUNT(*) AS registros FROM dim.DIM_DATA
UNION ALL SELECT 'DIM_CLIENTE', COUNT(*) FROM dim.DIM_CLIENTE
UNION ALL SELECT 'DIM_PRODUTO', COUNT(*) FROM dim.DIM_PRODUTO
UNION ALL SELECT 'DIM_REGIAO', COUNT(*) FROM dim.DIM_REGIAO
UNION ALL SELECT 'DIM_EQUIPE', COUNT(*) FROM dim.DIM_EQUIPE
UNION ALL SELECT 'DIM_VENDEDOR', COUNT(*) FROM dim.DIM_VENDEDOR
UNION ALL SELECT 'DIM_DESCONTO', COUNT(*) FROM dim.DIM_DESCONTO
UNION ALL SELECT 'FACT_VENDAS', COUNT(*) FROM fact.FACT_VENDAS
UNION ALL SELECT 'FACT_METAS', COUNT(*) FROM fact.FACT_METAS
UNION ALL SELECT 'FACT_DESCONTOS', COUNT(*) FROM fact.FACT_DESCONTOS
ORDER BY tabela;
PRINT '';

-- 7. Verificar Foreign Keys
PRINT '7. Foreign Keys:';
SELECT 
    OBJECT_NAME(fk.parent_object_id) AS fact_table,
    fk.name AS fk_name,
    OBJECT_NAME(fk.referenced_object_id) AS dimension_table
FROM sys.foreign_keys fk
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) IN ('fact', 'dim')
ORDER BY fact_table, fk_name;
PRINT '';

-- 8. Verificar Índices
PRINT '8. Total de Índices:';
SELECT 
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    COUNT(*) AS total_indices
FROM sys.indexes i
WHERE OBJECT_SCHEMA_NAME(i.object_id) IN ('dim', 'fact')
  AND i.type > 0
GROUP BY OBJECT_SCHEMA_NAME(i.object_id);
PRINT '';

PRINT '========================================';
PRINT '✅ VALIDAÇÃO CONCLUÍDA';
PRINT '========================================';
```

### Testes de Integridade

```sql
-- Teste 1: Verificar órfãos em FACT_VENDAS
SELECT COUNT(*) AS vendas_orfas
FROM fact.FACT_VENDAS fv
WHERE NOT EXISTS (SELECT 1 FROM dim.DIM_DATA d WHERE d.data_id = fv.data_id)
   OR NOT EXISTS (SELECT 1 FROM dim.DIM_CLIENTE c WHERE c.cliente_id = fv.cliente_id)
   OR NOT EXISTS (SELECT 1 FROM dim.DIM_PRODUTO p WHERE p.produto_id = fv.produto_id);
-- Esperado: 0

-- Teste 2: Verificar consistência de valores
SELECT 
    COUNT(*) AS registros,
    SUM(CASE WHEN valor_total_liquido <> (valor_total_bruto - valor_total_descontos) THEN 1 ELSE 0 END) AS inconsistencias
FROM fact.FACT_VENDAS;
-- Esperado: inconsistencias = 0

-- Teste 3: Verificar datas no futuro
SELECT COUNT(*) AS datas_futuro
FROM dim.DIM_DATA
WHERE data_completa > GETDATE();
-- Esperado: > 0 (futuro planejado)
```

---

## ⚠️ Troubleshooting

### Problema 1: "Database already exists"

```sql
-- Solução: Dropar e recriar
USE master;
GO
DROP DATABASE IF EXISTS DW_ECOMMERCE;
GO
-- Executar novamente 01_create_database.sql
```

### Problema 2: "Foreign key constraint failed"

**Causa:** Ordem incorreta de execução.

**Solução:**

```sql
-- 1. Verificar qual FK falhou
-- 2. Dropar fact/dimension problemática
-- 3. Recriar dimensão referenciada PRIMEIRO
-- 4. Recriar fact/dimension que depende DEPOIS

-- Exemplo: Se dim_vendedor falhar
DROP TABLE IF EXISTS dim.DIM_VENDEDOR;
GO
-- Garantir que dim_equipe existe
-- Executar 06_dim_vendedor.sql novamente
```

### Problema 3: "Object already exists"

```sql
-- Cada script tem DROP IF EXISTS no início
-- Se ainda ocorrer, forçar drop:
DROP TABLE IF EXISTS dim.DIM_VENDEDOR;
DROP TABLE IF EXISTS fact.FACT_VENDAS;
-- Etc...
```

### Problema 4: "Cannot insert NULL"

**Causa:** Dados de exemplo não foram populados.

**Solução:** Os scripts DDL já incluem INSERT de dados. Se necessário:

```sql
-- Verificar se dados foram inseridos
SELECT COUNT(*) FROM dim.DIM_DATA;

-- Se retornar 0, re-executar o script da dimensão
```

---

## 📞 Suporte

- **Dúvidas?** Abra uma [Issue](https://github.com/seu-usuario/project-e-commerce-dw/issues)
- **Encontrou um bug?** Reporte [aqui](https://github.com/seu-usuario/project-e-commerce-dw/issues)
- **Sugestões?** Use [Discussions](https://github.com/seu-usuario/project-e-commerce-dw/discussions)

---

## 📚 Próximos Passos

Após executar todos os scripts:

1. ✅ Executar [script de validação](#validação)
2. 📖 Ler [Visão Geral da Modelagem](../docs/modelagem/01_visao_geral.md)
3. 🔍 Explorar [Queries Analíticas](../docs/queries/README.md)
4. 📊 Criar seus próprios dashboards

---

<div align="center">

**[⬆ Voltar ao topo](#-scripts-sql---guia-de-execução)**

</div>
