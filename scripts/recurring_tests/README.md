# Testes Recorrentes

Scripts de validacao operacional para execucao recorrente (manual, agendada ou CI).

## Suite consolidada (Dia 4)

Executa em sequencia:

- smoke de filtros de vendas;
- smoke de filtros de metas;
- smoke de filtros de descontos/ROI;
- checks minimos de integridade no DW.

Execucao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_day4_recurring_tests.ps1
```

Saida JSON consolidada:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_day4_recurring_tests.ps1 -Json
```

Saida JSON consolidada em arquivo (uso CI/agendamento):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_day4_recurring_tests.ps1 -Json -OutputPath scripts/recurring_tests/artifacts/day4_suite.json
```

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

## Dashboard de Metas - Smoke de Filtros

Valida os filtros do app `dashboards/streamlit/metas/app.py`.

Execucao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_metas_filter_smoke.ps1
```

Saida JSON:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_metas_filter_smoke.ps1 -Json
```

## Dashboard de Descontos/ROI - Smoke de Filtros

Valida os filtros do app `dashboards/streamlit/descontos/app.py`.

Execucao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_descontos_filter_smoke.ps1
```

Saida JSON:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dash_descontos_filter_smoke.ps1 -Json
```

## DW - Integridade minima

Checks automatizados:

- FK orfa nas tabelas fato principais;
- duplicidade de chaves naturais (dimensoes/fatos);
- cobertura minima de tabelas e views de consumo.

Execucao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dw_integrity_minimum.ps1
```

Saida JSON:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_dw_integrity_minimum.ps1 -Json
```

### Recomendacao de cadencia

- Diario apos janela de ETL.
- Antes de publicar alteracoes nos dashboards em `dashboards/streamlit/*/app.py`.
- Em CI agendado, preferir `run_day4_recurring_tests.ps1 -Json`.
