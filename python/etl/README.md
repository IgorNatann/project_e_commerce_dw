# ETL Python - estado atual

Pipeline ETL incremental com foco inicial em `dim_cliente` e onboarding tecnico da `dim_produto`.

## O que esta pronto

- Extracao incremental por watermark (`updated_at`, `id`).
- Transformacao e upsert Type 1 para `dim_cliente`.
- Transformacao e upsert Type 1 para `dim_produto`.
- Auditoria de execucao em `audit.etl_run` e `audit.etl_run_entity`.
- Monitoramento visual via Streamlit.

## Fluxo recomendado com Docker

1. Subir a infra:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

2. Abrir monitoramento:

- `http://localhost:8501`

3. Executar ETL da entidade no mesmo container do monitor:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_produto
```

4. Opcional: executar ETL local (fora do container), configurando variaveis `ETL_*`:

```powershell
python python/etl/run_etl.py --entity dim_cliente
python python/etl/run_etl.py --entity dim_produto
```

## Variaveis de conexao

As variaveis usadas pelo ETL estao em `python/etl/config.py` (prefixo `ETL_`).
Se for rodar localmente fora dos containers, ajuste para apontar ao SQL Server da stack Docker (`localhost:1433`).

## Estrutura

```text
python/etl/
|-- run_etl.py
|-- config.py
|-- db.py
|-- control.py
|-- entities/
|   |-- dim_cliente.py
|   `-- dim_produto.py
|-- sql/
|   |-- extract_dim_cliente.sql
|   |-- extract_dim_produto.sql
|   |-- upsert_dim_cliente.sql
|   |-- upsert_dim_produto.sql
|   `-- update_watermark.sql
|-- monitoring/
|   |-- app.py
|   `-- requirements.txt
`-- docs/
    |-- 01_fluxo_geral.md
    |-- 02_como_executar.md
    |-- 03_troubleshooting.md
    |-- 04_fluxo_visual.md
    |-- 05_monitoramento_streamlit.md
    `-- 06_validacao_dim_cliente_e2e.md
```

## Proximo passo natural

Depois de estabilizar `dim_cliente`/`dim_produto` (auditoria + monitoramento), replicar o padrao para as demais entidades.
