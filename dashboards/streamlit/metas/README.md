# Dashboard de Metas (R1)

Aplicacao Streamlit para consumo de indicadores de metas e atingimento com base em `fact.VW_DASH_METAS_R1`.

## Objetivo

- Expor KPIs de meta total, realizado total, atingimento e gap.
- Suportar analise por regional, equipe e vendedor.
- Consolidar o escopo de metas do PRD com dicionario de metricas e SQL de referencia (RF-13).

## Execucao local

```powershell
streamlit run dashboards/streamlit/metas/app.py
```

## Variaveis de ambiente

- `DASH_METAS_SQL_DRIVER` (default: `ODBC Driver 18 for SQL Server`)
- `DASH_METAS_SQL_SERVER` (default: `sqlserver`)
- `DASH_METAS_SQL_PORT` (default: `1433`)
- `DASH_METAS_DW_DB` (default: `DW_ECOMMERCE`)
- `DASH_METAS_SQL_USER` (default: `bi_reader`)
- `DASH_METAS_SQL_PASSWORD` (obrigatoria)
- `DASH_METAS_SQL_ENCRYPT` (default: `yes`)
- `DASH_METAS_SQL_TRUST_SERVER_CERTIFICATE` (default: `yes`)
- `DASH_METAS_SQL_TIMEOUT_SECONDS` (default: `120`)
- `DASH_METAS_TIMEZONE` (default: `America/Sao_Paulo`) para avaliacao de SLA D+1 08:00
- `USE_SNAPSHOT` (opcional, override global `true|false`)
- `DASH_METAS_USE_SNAPSHOT` (default: `false`; ativa leitura offline de snapshot)
- `DASH_METAS_SNAPSHOT_PATH` (default: `data/snapshots/metas_r1.csv.gz`)

## Modo snapshot (portfolio/community cloud)

Gerar snapshots locais:

```powershell
python scripts/snapshots/export_dash_snapshots.py
```

Executar dashboard com snapshot:

```powershell
$env:DASH_METAS_USE_SNAPSHOT = "true"
streamlit run dashboards/streamlit/metas/app.py
```

## Dependencias

Arquivo: `dashboards/streamlit/metas/requirements.txt`.

## SQL de homologacao

- View de consumo: `sql/dw/04_views/13_vw_dash_metas_r1.sql`
- Query de referencia: `docs/queries/metas/01_kpis_dash_metas_r1.sql`

## Smoke recorrente de filtros

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_metas_filter_smoke.ps1
```
