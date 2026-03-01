# Plano de Fechamento Portfolio MVP

Data de inicio: 2026-02-28  
Janela planejada: 7 dias (ate 2026-03-06)  
Baseline atual: 72%  
Meta de fechamento: >= 90%

## 1) Objetivo

Fechar o projeto em nivel "portfolio-ready" mantendo Streamlit no MVP, com:

- monitoria ETL funcional e acessivel;
- dashboards de negocio principais publicados;
- validacoes automatizadas minimas;
- runbook e evidencias de operacao.

## 2) Como preencher este plano

Atualize este arquivo ao final de cada entrega:

- `Status`: `nao_iniciado | em_andamento | concluido | bloqueado`
- `Responsavel`: nome/alias
- `Evidencia`: caminhos de arquivo, comando executado, print ou link
- `Delta`: percentual antes/depois (ex.: `72 -> 75`)

## 3) Score 0-100 (controle rapido)

Preencha semanalmente:

- `Percentual atual`: 89
- `Percentual alvo`: 90
- `Ultima atualizacao`: 2026-02-28

Sugestao de criterio:

- 0-59: base incompleta
- 60-79: MVP funcional
- 80-89: quase portfolio-ready
- 90-100: portfolio-ready

## 4) Cronograma executavel (7 dias)

### Dia 1 - 2026-02-28 - Baseline documental

Status: concluido  
Responsavel: Igor/Codex  
Delta: 72 -> 74  

Checklist:

- [x] Ajustar inconsistencias entre `README.md`, `docs/produto/PRD.md` e status report.
- [x] Registrar fonte unica do "estado atual" no repositorio.
- [x] Garantir que backlog P0 reflita o que realmente falta.

Evidencia:

- Arquivos alterados: `README.md`, `docs/produto/PRD.md`, `docs/status_reports/2026-02-28.md`
- Commits/PR: branch local `chore/dia1-alinhamento-documental-portfolio`

Validacao:

```powershell
rg -n "Status de evolucao|Lacunas criticas|P0-" README.md docs/produto/PRD.md docs/status_reports/2026-02-28.md -S
```

---

### Dia 2 - 2026-03-01 - Dashboard Metas

Status: concluido  
Responsavel: Igor/Codex  
Delta: 74 -> 78  

Checklist:

- [x] Criar app Streamlit de metas/atingimento em `dashboards/streamlit/metas`.
- [x] Criar README operacional do dashboard de metas.
- [x] Adicionar build/deploy no Docker (novo servico).
- [x] Publicar query SQL de referencia dos KPIs de metas.

Evidencia:

- Arquivos alterados: `dashboards/streamlit/metas/*`, `docker/streamlit-metas.Dockerfile`, `docker/docker-compose.sqlserver.yml`, `sql/dw/04_views/13_vw_dash_metas_r1.sql`, `docs/queries/metas/01_kpis_dash_metas_r1.sql`
- URL local/publica: `http://localhost:8503` (local)
- Observacao: entrega executada antecipadamente em 2026-02-28.

Validacao:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
```

---

### Dia 3 - 2026-03-02 - Dashboard Descontos/ROI

Status: concluido  
Responsavel: Igor/Codex  
Delta: 78 -> 82  

Checklist:

- [x] Criar app Streamlit de descontos/ROI em `dashboards/streamlit/descontos`.
- [x] Criar README operacional do dashboard de descontos.
- [x] Adicionar build/deploy no Docker (novo servico).
- [x] Publicar query SQL de referencia de ROI/impacto de margem.

Evidencia:

- Arquivos alterados: `dashboards/streamlit/descontos/*`, `docker/streamlit-descontos.Dockerfile`, `docker/docker-compose.sqlserver.yml`, `sql/dw/04_views/14_vw_dash_descontos_r1.sql`, `docs/queries/descontos/01_kpis_dash_descontos_r1.sql`
- URL local/publica: `http://localhost:8504` (local)
- Observacao: entrega executada antecipadamente em 2026-02-28.

Validacao:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
```

---

### Dia 4 - 2026-03-03 - Testes automatizados

Status: concluido  
Responsavel: Igor/Codex  
Delta: 82 -> 86  

Checklist:

- [x] Consolidar smoke de filtros para vendas, metas e descontos.
- [x] Criar checks de integridade minima (FK orfa, duplicidade NK, cobertura minima).
- [x] Padronizar saida JSON para execucao manual/agendada/CI.

Evidencia:

- Arquivos alterados: `scripts/recurring_tests/*` (novos runners/validadores de metas, descontos, integridade DW e suite consolidada), `dashboards/streamlit/metas/README.md`, `dashboards/streamlit/descontos/README.md`
- Artefatos JSON: `scripts/recurring_tests/artifacts/day4_suite.json` (gerado via `-OutputPath`)

Validacao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/recurring_tests/run_day4_recurring_tests.ps1 -Json
```

---

### Dia 5 - 2026-03-04 - Alertas externos

Status: concluido  
Responsavel: Igor/Codex  
Delta: 86 -> 89  

Checklist:

- [x] Definir canal de alerta (Discord/Slack/Teams/Webhook).
- [x] Implementar alerta para falha de pipeline ETL.
- [x] Implementar alerta para atraso de SLA.
- [x] Documentar variaveis de ambiente e fallback.

Evidencia:

- Arquivos alterados: `scripts/alerts/check_and_alert.py`, `scripts/alerts/README.md`, `scripts/alerts/requirements.txt`, `docker/alerts-runner.Dockerfile`, `docker/docker-compose.sqlserver.yml`, `docker/.env.sqlserver.example`, `docker/up_stack.ps1`, `docker/README.md`, `README.md`
- Captura de alerta recebido: `docker logs --tail 50 dw_alert_runner` (runner ativo; envio externo depende de `ALERT_ENABLED=true` + webhook)
- Observacao: entrega executada antecipadamente em 2026-02-28.

Validacao:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
docker logs --tail 50 dw_alert_runner
```

---

### Dia 6 - 2026-03-05 - Deploy portfolio

Status: em_andamento  
Responsavel: Igor/Codex  
Delta: 89 -> 89  

Checklist:

- [ ] Publicar stack em ambiente acessivel externamente.
- [ ] Garantir que banco nao fique exposto publicamente.
- [ ] Definir URL publica dos dashboards.
- [ ] Confirmar healthchecks e restart policy.

Evidencia:

- Preparacao snapshot pronta: `dashboards/streamlit/vendas/app.py`, `dashboards/streamlit/metas/app.py`, `dashboards/streamlit/descontos/app.py`, `scripts/snapshots/export_dash_snapshots.py`, `scripts/snapshots/README.md`
- Ambiente/host: pendente
- URLs publicas: pendente

Validacao:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
```

---

### Dia 7 - 2026-03-06 - Runbook + Go/No-Go final

Status: nao_iniciado  
Responsavel:  
Delta:  ->  

Checklist:

- [ ] Publicar runbook de rotina, incidente e recuperacao.
- [ ] Consolidar checklist final de aceite.
- [ ] Registrar evidencias de 7 dias de operacao.
- [ ] Atualizar README principal com links finais de portfolio.

Evidencia:

- Arquivos alterados:
- Resultado Go/No-Go:

Validacao:

```powershell
rg -n "runbook|go/no-go|portfolio|dashboard" README.md docs -S
```

## 5) Checklist final (Definition of Done Portfolio)

- [ ] ETL executa ponta a ponta sem erro critico por 7 dias.
- [ ] Monitoria Streamlit mostra status, falhas e SLA corretamente.
- [ ] Dashboards de vendas, metas e descontos publicados.
- [ ] Testes recorrentes executando com artefato JSON.
- [x] Alertas externos ativos para falha e atraso.
- [ ] Runbook operacional completo e versionado.
- [ ] README com arquitetura, como executar e links de demo.
- [ ] Seguranca minima aplicada para exposicao publica.

## 6) Log de progresso

| Data | Item | Status | Evidencia | Observacoes |
|---|---|---|---|---|
| 2026-02-28 | Plano criado | concluido | `docs/produto/PLANO_FECHAMENTO_PORTFOLIO_MVP.md` | Baseline inicial 72% |
| 2026-02-28 | Dia 1 - baseline documental | concluido | `README.md`, `docs/produto/PRD.md`, `docs/status_reports/2026-02-28.md` | Escopo facts alinhado e P0 atualizado |
| 2026-02-28 | Dia 2 - dashboard metas | concluido | `dashboards/streamlit/metas/*`, `docker/streamlit-metas.Dockerfile`, `sql/dw/04_views/13_vw_dash_metas_r1.sql` | Dashboard metas R1 publicado no stack |
| 2026-02-28 | Dia 3 - dashboard descontos/ROI | concluido | `dashboards/streamlit/descontos/*`, `docker/streamlit-descontos.Dockerfile`, `sql/dw/04_views/14_vw_dash_descontos_r1.sql` | Dashboard descontos/ROI R1 publicado no stack |
| 2026-02-28 | Dia 4 - testes automatizados | concluido | `scripts/recurring_tests/*`, `dashboards/streamlit/metas/README.md`, `dashboards/streamlit/descontos/README.md` | Suite consolidada com 60/60 checks aprovados |
| 2026-02-28 | Dia 5 - alertas externos ETL | concluido | `scripts/alerts/*`, `docker/alerts-runner.Dockerfile`, `docker/docker-compose.sqlserver.yml`, `docker/up_stack.ps1` | Runner Discord/Webhook com cooldown, estado persistente e fallback seguro |
| 2026-02-28 | Dia 6 - adaptacao snapshot para deploy gratuito | em_andamento | `dashboards/streamlit/*/app.py`, `scripts/snapshots/*` | Dashboards aptos a rodar sem SQL ativo (modo snapshot) |

## 7) Blocos de validacao continua (para o Codex seguir evoluindo)

Quando continuar a evolucao, validar sempre:

1. Escopo ativo em `ctl.etl_control` bate com entidades implementadas.
2. Dashboards e compose estao consistentes (servicos, portas, healthcheck).
3. Testes recorrentes possuem comando unico e saida estruturada.
4. Documentacao reflete exatamente o estado real do codigo.
