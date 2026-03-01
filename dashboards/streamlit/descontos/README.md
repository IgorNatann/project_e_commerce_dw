# Dashboard de Descontos e ROI (R1)

Aplicacao Streamlit para consumo de indicadores de descontos, impacto de margem e ROI com base em `fact.VW_DASH_DESCONTOS_R1`.

## Objetivo

- Expor KPIs de desconto total concedido, receita com desconto e ROI.
- Suportar analise por tipo/metodo/codigo de desconto, nivel de aplicacao e regiao.
- Consolidar o escopo de descontos do PRD com dicionario de metricas e SQL de referencia (RF-13).

## Execucao local

```powershell
streamlit run dashboards/streamlit/descontos/app.py
```

## Variaveis de ambiente

- `DASH_DESC_SQL_DRIVER` (default: `ODBC Driver 18 for SQL Server`)
- `DASH_DESC_SQL_SERVER` (default: `sqlserver`)
- `DASH_DESC_SQL_PORT` (default: `1433`)
- `DASH_DESC_DW_DB` (default: `DW_ECOMMERCE`)
- `DASH_DESC_SQL_USER` (default: `bi_reader`)
- `DASH_DESC_SQL_PASSWORD` (obrigatoria)
- `DASH_DESC_SQL_ENCRYPT` (default: `yes`)
- `DASH_DESC_SQL_TRUST_SERVER_CERTIFICATE` (default: `yes`)
- `DASH_DESC_SQL_TIMEOUT_SECONDS` (default: `120`)
- `DASH_DESC_TIMEZONE` (default: `America/Sao_Paulo`) para avaliacao de SLA D+1 08:00
- `USE_SNAPSHOT` (opcional, override global `true|false`)
- `DASH_DESC_USE_SNAPSHOT` (default: `false`; ativa leitura offline de snapshot)
- `DASH_DESC_SNAPSHOT_PATH` (default: `data/snapshots/descontos_r1.csv.gz`)

## Modo snapshot (portfolio/community cloud)

Gerar snapshots locais:

```powershell
python scripts/snapshots/export_dash_snapshots.py
```

Executar dashboard com snapshot:

```powershell
$env:DASH_DESC_USE_SNAPSHOT = "true"
streamlit run dashboards/streamlit/descontos/app.py
```

## Dependencias

Arquivo: `dashboards/streamlit/descontos/requirements.txt`.

## SQL de homologacao

- View de consumo: `sql/dw/04_views/14_vw_dash_descontos_r1.sql`
- Query de referencia: `docs/queries/descontos/01_kpis_dash_descontos_r1.sql`

## Smoke recorrente de filtros

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_descontos_filter_smoke.ps1
```
