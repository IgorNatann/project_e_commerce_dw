# Dashboard de Vendas (R1)

Aplicacao Streamlit para consumo de indicadores comerciais com base em `fact.FACT_VENDAS`.

## Objetivo

- Expor KPIs principais de vendas para usuarios de negocio.
- Manter separacao entre monitoria ETL tecnica (`:8501`) e consumo de negocio (`:8502`).
- Consolidar o escopo de vendas do PRD com dicionario de metricas e SQL de referencia (RF-13).

## Execucao local

```powershell
streamlit run python/dashboards/vendas/app.py
```

## Variaveis de ambiente

- `DASH_SQL_DRIVER` (default: `ODBC Driver 18 for SQL Server`)
- `DASH_SQL_SERVER` (default: `sqlserver`)
- `DASH_SQL_PORT` (default: `1433`)
- `DASH_DW_DB` (default: `DW_ECOMMERCE`)
- `DASH_SQL_USER` (default: `bi_reader`)
- `DASH_SQL_PASSWORD` (obrigatoria)
- `DASH_SQL_ENCRYPT` (default: `yes`)
- `DASH_SQL_TRUST_SERVER_CERTIFICATE` (default: `yes`)
- `DASH_SQL_TIMEOUT_SECONDS` (default: `120`)
- `DASH_TIMEZONE` (default: `America/Sao_Paulo`) para avaliacao de SLA D+1 08:00

## Dependencias

Arquivo: `python/dashboards/vendas/requirements.txt`.
