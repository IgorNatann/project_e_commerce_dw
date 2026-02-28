# Dashboards

Centraliza os ativos de consumo analitico do projeto.

## Estrutura

```text
dashboards/
|-- streamlit/
|   |-- monitoring/
|   |-- vendas/
|   `-- metas/
|-- metabase/
`-- queries/
```

## Streamlit

- Monitoramento ETL: `dashboards/streamlit/monitoring/app.py`
- Vendas R1: `dashboards/streamlit/vendas/app.py`
- Metas R1: `dashboards/streamlit/metas/app.py`

Execucao local:

```powershell
streamlit run dashboards/streamlit/monitoring/app.py
streamlit run dashboards/streamlit/vendas/app.py
streamlit run dashboards/streamlit/metas/app.py
```

## Docker

- Build monitor: `docker/streamlit-monitor.Dockerfile`
- Build vendas: `docker/streamlit-vendas.Dockerfile`
- Build metas: `docker/streamlit-metas.Dockerfile`

