# Testes Recorrentes

Scripts de validacao operacional para execucao recorrente (manual, agendada ou CI).

## Dashboard de Vendas - Smoke de Filtros

Valida os filtros do app `dashboards/streamlit/vendas/app.py` usando o mesmo carregamento de dados do dashboard.

### Pre-requisitos

- Stack Docker ativa (`dw_dash_vendas` e `dw_sqlserver` em `healthy`).

### Execucao

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_vendas_filter_smoke.ps1
```

Saida JSON (para pipeline/CI):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_vendas_filter_smoke.ps1 -Json
```

### Recomendacao de cadencia

- Diario apos janela de ETL.
- Antes de publicar alteracoes em `dashboards/streamlit/vendas/app.py`.
