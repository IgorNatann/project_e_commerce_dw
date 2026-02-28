# Scripts De Evolucao

Automacoes para documentar evolucao do projeto no portfolio.

## Nota de infra

Estes scripts sao independentes da stack Docker (`docker/up_stack.ps1`).

## Scripts

- `generate_daily_reports.py`: gera/atualiza relatorios diarios em `docs/evolucao_diaria/`
- `generate_monthly_reports.py`: gera/atualiza relatorios mensais em `docs/evolucao_mensal/`
- `generate_milestones.py`: consolida marcos em `docs/evolucao_marcos/`
- `run_all.py`: executa diario + mensal + marcos

## Uso Rapido

Atualizacao diaria (incremental):

`python scripts/evolution/generate_daily_reports.py`

Atualizacao mensal (incremental):

`python scripts/evolution/generate_monthly_reports.py`

Consolidar marcos:

`python scripts/evolution/generate_milestones.py`

Gerar tudo de uma vez:

`python scripts/evolution/run_all.py`
