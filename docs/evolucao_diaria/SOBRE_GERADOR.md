# Sobre A Automacao De Evolucao

## Objetivo

Documentar a evolucao tecnica do projeto para portfolio em tres niveis:

- diario: `docs/evolucao_diaria/`
- mensal: `docs/evolucao_mensal/`
- marcos: `docs/evolucao_marcos/`

Scripts centrais:

- `scripts/evolution/generate_daily_reports.py`
- `scripts/evolution/generate_monthly_reports.py`
- `scripts/evolution/generate_milestones.py`
- `scripts/evolution/run_all.py`

## O Que Cada Script Faz

### Diario

Gera um arquivo por dia (`YYYY-MM-DD.md`) com:

- volume de commits (merge e no-merge)
- volume de codigo (+/-)
- autores, areas tocadas e tipos de commit
- lista de commits de trabalho e integracao

### Mensal

Gera um arquivo por mes (`YYYY-MM.md`) com:

- consolidado do mes
- distribuicao diaria
- autores, areas e tipos
- lista de commits de trabalho e integracao do mes

### Marcos

Gera `docs/evolucao_marcos/MARCOS.md` com:

- timeline por mes
- consolidado de indicadores por marco
- destaques de entregas por mes

## Como A Automacao Funciona

1. lê o historico Git com filtros de periodo (`--since` / `--until`)
2. calcula metricas de commits e diff (`numstat`)
3. organiza resultados em markdown
4. atualiza os indices (`README.md`) das pastas de evolucao

## Sua Duvida: "Quando eu rodar de novo, ele percorre o repositorio inteiro?"

Depende do modo:

- `full`: sim, reprocessa todo historico.
- `incremental`: nao, processa apenas o ultimo periodo gerado + novos periodos.

No seu fluxo:

- usar `incremental` no dia a dia
- usar `full` pontualmente para reconciliar tudo

## Comandos Recomendados

Gerar tudo de uma vez (recomendado):

`python scripts/evolution/run_all.py`

Apenas diario:

`python scripts/evolution/generate_daily_reports.py`

Apenas mensal:

`python scripts/evolution/generate_monthly_reports.py`

Apenas marcos:

`python scripts/evolution/generate_milestones.py`

## Estrutura Atual

Os comandos oficiais ficam apenas em `scripts/evolution/`.
