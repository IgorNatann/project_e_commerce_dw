# Evolucao Mensal Do Projeto

Relatorios mensais gerados a partir do historico Git.

## Nota de infra

Este fluxo e independente da stack Docker (`docker/up_stack.ps1`).

## Como Atualizar

Mensal incremental (recomendado):

python scripts/evolution/generate_monthly_reports.py

Mensal full:

python scripts/evolution/generate_monthly_reports.py --mode full

Gerar tudo (diario + mensal + marcos):

python scripts/evolution/run_all.py

## Indice De Meses

| mes | total commits | no merges | merges | relatorio |
|---|---:|---:|---:|---|
| 2026-02 | 44 | 21 | 23 | [abrir](2026-02.md) |
| 2026-01 | 12 | 7 | 5 | [abrir](2026-01.md) |
| 2025-12 | 89 | 55 | 34 | [abrir](2025-12.md) |
