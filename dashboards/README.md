# Dashboards

Centraliza os ativos de consumo analitico do projeto.

## Estrutura

```text
dashboards/
|-- streamlit/
|   |-- monitoring/
|   `-- vendas/
|-- metabase/
`-- queries/
```

## Streamlit

- Monitoramento ETL: `dashboards/streamlit/monitoring/app.py`
- Vendas R1: `dashboards/streamlit/vendas/app.py`

Execucao local:

```powershell
streamlit run dashboards/streamlit/monitoring/app.py
streamlit run dashboards/streamlit/vendas/app.py
```

## Docker

- Build monitor: `docker/streamlit-monitor.Dockerfile`
- Build vendas: `docker/streamlit-vendas.Dockerfile`

