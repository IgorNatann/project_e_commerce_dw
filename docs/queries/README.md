# Queries analiticas

Guia de consultas para validar ambiente e explorar dados.

## Pre-requisito

Subir stack Docker:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

## Escopo atual da stack

O bootstrap da infra garante principalmente:

- OLTP pronto (`ECOMMERCE_OLTP`)
- DW com `dim.DIM_CLIENTE`
- controle ETL e auditoria (`ctl` e `audit`)

Consultas que dependem de tabelas fato e outras dimensoes exigem carga adicional/manual.

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

## Expansao para analytics completo

Quando as proximas dimensoes e fatos estiverem carregadas, este README pode ser estendido com as consultas de vendas, performance, geografia e campanhas.
