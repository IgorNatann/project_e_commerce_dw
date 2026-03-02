# Queries analiticas

Guia de consultas para validar ambiente e explorar dados.

## Pre-requisito

Subir stack Docker:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

## Escopo atual da stack

O bootstrap da infra garante:

- OLTP pronto (`ECOMMERCE_OLTP`)
- DW com dimensoes e fatos do rollout atual
- fatos `fact.FACT_VENDAS`, `fact.FACT_METAS` e `fact.FACT_DESCONTOS`
- controle ETL e auditoria (`ctl` e `audit`)
- views de consumo R1 (`fact.VW_DASH_VENDAS_R1`, `fact.VW_DASH_METAS_R1`, `fact.VW_DASH_DESCONTOS_R1`)

As queries deste diretorio podem ser executadas imediatamente apos o `docker/up_stack.ps1`.

## Queries de validacao imediata

### 1) Clientes no DW

```sql
USE DW_ECOMMERCE;
GO

SELECT TOP 20
    cliente_id,
    nome_cliente,
    email,
    segmento,
    data_ultima_atualizacao
FROM dim.DIM_CLIENTE
ORDER BY data_ultima_atualizacao DESC;
```

### 2) Controle ETL ativo

```sql
USE DW_ECOMMERCE;
GO

SELECT
    entity_name,
    is_active,
    watermark_updated_at,
    watermark_id,
    last_status,
    last_success_at
FROM ctl.etl_control
ORDER BY entity_name;
```

### 3) Ultimas execucoes ETL

```sql
USE DW_ECOMMERCE;
GO

SELECT TOP 20
    run_id,
    entity_name,
    status,
    extracted_count,
    upserted_count,
    soft_deleted_count,
    entity_started_at,
    entity_finished_at
FROM audit.etl_run_entity
ORDER BY run_entity_id DESC;
```

### 4) Auditoria de conexao (tabela)

```sql
USE DW_ECOMMERCE;
GO

SELECT TOP 50
    event_time_utc,
    login_name,
    host_name,
    program_name,
    client_net_address
FROM audit.connection_login_events
ORDER BY event_time_utc DESC;
```

## Evolucao sugerida

Para proxima fase, expandir este README com consultas de:

- desempenho/latencia das views no volume real;
- reconciliacao diaria automatizada (OLTP x DW) por entidade;
- qualidade de dados por regra de negocio (alem dos KPIs de homologacao).

## Queries de homologacao do dashboard de vendas R1

Arquivo de referencia:

- `docs/queries/vendas/01_kpis_dash_vendas_r1.sql`

Uso:

- definir `@data_inicio` e `@data_fim` iguais ao filtro de periodo aplicado no dashboard;
- executar o script e comparar KPIs principais (receita, margem, devolucao, ticket e desconto medio).

## Queries de homologacao do dashboard de metas R1

Arquivo de referencia:

- `docs/queries/metas/01_kpis_dash_metas_r1.sql`

Uso:

- definir `@data_inicio` e `@data_fim` iguais ao filtro de periodo aplicado no dashboard;
- executar o script e comparar KPIs principais (meta total, realizado, atingimento, gap e taxa de meta batida).

## Queries de homologacao do dashboard de descontos/ROI R1

Arquivo de referencia:

- `docs/queries/descontos/01_kpis_dash_descontos_r1.sql`

Uso:

- definir `@data_inicio` e `@data_fim` iguais ao filtro de periodo aplicado no dashboard;
- executar o script e comparar KPIs principais (desconto total, receita com desconto, ROI, impacto de margem e taxa de aprovacao).
