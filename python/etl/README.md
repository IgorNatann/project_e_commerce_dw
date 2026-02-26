# ETL Python - Fase 3 (Didatico)

Este diretorio contem uma base simples de ETL incremental para iniciantes.
O foco inicial e carregar a dimensao `dim_cliente` com:

- leitura incremental por watermark (`updated_at`, `id`);
- transformacao basica;
- upsert Type 1;
- auditoria de execucao;
- avancar watermark apenas em sucesso.

## Estrutura

```text
python/etl/
|-- README.md
|-- run_etl.py
|-- config.py
|-- db.py
|-- control.py
|-- entities/
|   |-- __init__.py
|   `-- dim_cliente.py
|-- sql/
|   |-- extract_dim_cliente.sql
|   |-- upsert_dim_cliente.sql
|   `-- update_watermark.sql
`-- docs/
    |-- 01_fluxo_geral.md
    |-- 02_como_executar.md
    |-- 03_troubleshooting.md
    |-- 04_fluxo_visual.md
    `-- 05_monitoramento_streamlit.md
```

## Primeira execucao (resumo)

1. Execute os scripts SQL de controle ETL em `sql/dw/03_etl_control`.
2. Configure variaveis de ambiente (ver `docs/02_como_executar.md`).
3. Rode:

```powershell
python python/etl/run_etl.py --entity dim_cliente
```

## Objetivo desta base

Manter o codigo facil de ler e alterar.
Depois que `dim_cliente` estiver estavel, replicar o mesmo padrao para:

- `dim_produto`
- `dim_regiao`
- `dim_equipe`
- `dim_desconto`
- `dim_vendedor`

## Documentacao recomendada de leitura

1. `docs/01_fluxo_geral.md`
2. `docs/04_fluxo_visual.md`
3. `docs/02_como_executar.md`
4. `docs/03_troubleshooting.md`
5. `docs/05_monitoramento_streamlit.md`

## Monitoramento visual

Dashboard Streamlit (estado do ETL):

```powershell
python -m streamlit run python/etl/monitoring/app.py
```
