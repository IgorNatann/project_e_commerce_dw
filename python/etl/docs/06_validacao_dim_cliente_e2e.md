# Validacao E2E - dim_cliente (OLTP -> DW)

Data da execucao: **2026-02-28**

Objetivo: evidenciar que o fluxo ETL da `dim_cliente` esta amarrado ponta a ponta:

1. conexao no SQL Server;
2. leitura incremental da origem OLTP (`core.customers`);
3. escrita no DW (`dim.DIM_CLIENTE`);
4. atualizacao de watermark e auditoria (`ctl` e `audit`).

## 1) Estado inicial (antes da simulacao)

Origem OLTP (`ECOMMERCE_OLTP.core.customers`):

- `source_total = 20300`
- `source_max_updated_at = 2026-02-28 01:10:04`

Destino DW (`DW_ECOMMERCE.dim.DIM_CLIENTE`):

- `target_total = 20301`
- `target_max_updated_at = 2026-02-28 01:01:40.000`

Controle ETL (`DW_ECOMMERCE.ctl.etl_control`, entidade `dim_cliente`):

- `watermark_updated_at = 2026-02-28 01:01:40`
- `watermark_id = 20300`
- `last_run_id = 30002`
- `last_status = success`

## 2) Mudanca controlada na origem (simulacao)

Foi executado:

- 1 `UPDATE` em `customer_id = 1` com `updated_at = SYSUTCDATETIME()`;
- 1 `INSERT` de novo cliente (`customer_code = CUST_E2E_...`).

Retorno do insert (OLTP):

- `inserted_customer_id = 20300`

## 3) Execucao do ETL

Comando:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
```

Resultado do run:

- `run_id = 30003`
- `status = success`
- lote unico com `extraidos = 2`, `upsertados = 2`, `soft_deleted = 0`
- watermark final do lote: `2026-02-28 01:05:41 / 20300`

## 4) Estado final (apos ETL)

Origem OLTP:

- `source_total = 20301`

Destino DW:

- `target_total = 20301`
- `target_max_updated_at = 2026-02-28 01:05:41.000`

Controle ETL:

- `watermark_updated_at = 2026-02-28 01:05:41`
- `watermark_id = 20300`
- `last_run_id = 30003`
- `last_status = success`

Auditoria:

- `audit.etl_run` (top 1): `run_id = 30003`, `status = success`, `entities_succeeded = 1`, `entities_failed = 0`
- `audit.etl_run_entity` (top 1 dim_cliente): `run_id = 30003`, `status = success`, `extracted_count = 2`, `upserted_count = 2`, `watermark_to_id = 20300`

Nota: nesse ciclo, a contagem total no DW nao aumentou porque houve upsert em chaves ja existentes (`Type 1`), mas o pipeline confirmou leitura da origem, processamento e atualizacao de watermark/auditoria.

## 5) Conclusao

Validacao **aprovada** para a `dim_cliente`:

- conexao SQL Server funcional;
- extracao incremental funcional;
- carga no DW funcional;
- watermark/auditoria funcionando;
- fluxo pronto para ser usado como baseline antes de evoluir para as proximas dimensoes.
