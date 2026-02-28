# Checklist de Implementacao - Dashboard de Vendas (R1)

Objetivo final: disponibilizar e consumir o dashboard de vendas em ambiente Docker, com dados confiaveis do DW.

Guia de execucao passo a passo: `docs/produto/PLAYBOOK_IMPL_DASH_VENDAS_R1.md`.

## 1. Preparacao de dados (DW)

- [ ] Validar carga da `fact_vendas` sem erros no `audit.etl_run_entity`.
- [ ] Confirmar reconciliacao `OLTP -> DW` da `fact_vendas` (contagem e watermark).
- [ ] Garantir FKs validas em `fact.FACT_VENDAS` (`data`, `cliente`, `produto`, `regiao`, `vendedor`).
- [ ] Executar smoke query de negocio (receita, ticket medio, volume por periodo).

## 2. Camada de consumo SQL

- [ ] Definir dataset de consumo (view unica ou conjunto de views).
- [ ] Criar view base de vendas para o dashboard (ex.: `fact.VW_VENDAS_COMPLETA` ou equivalente R1).
- [ ] Validar performance das queries principais (alvo <= 10s no volume atual).
- [ ] Congelar definicoes de KPI (receita liquida, margem, ticket medio, devolucao).

## 3. Seguranca e acessos

- [ ] Criar login tecnico de BI somente leitura (ex.: `bi_reader`).
- [ ] Conceder apenas `SELECT` em schemas/objetos de consumo (`fact`, `dim`, views).
- [ ] Negar acesso de escrita para usuario do dashboard.
- [ ] Testar conexao com credencial dedicada.

## 4. Aplicacao do dashboard (Streamlit)

- [ ] Criar app do dashboard em pasta dedicada (ex.: `dashboards/streamlit/vendas/app.py`).
- [ ] Implementar filtros minimos: periodo, regiao, categoria, vendedor.
- [ ] Implementar KPIs principais na tela inicial.
- [ ] Implementar pelo menos 3 visuais analiticos (tendencia temporal, mix produto, geografico/comercial).
- [ ] Tratar estados de erro, vazio e timeout de consulta.
- [ ] Expor dicionario de metricas no app (RF-13 do PRD).

## 5. Containerizacao e deploy

- [ ] Criar Dockerfile dedicado do dashboard (separado do monitor ETL).
- [ ] Adicionar novo servico no `docker-compose` (ex.: `streamlit-vendas` em `:8502`).
- [ ] Configurar variaveis de ambiente para conexao SQL do dashboard.
- [ ] Subir stack e validar healthcheck do novo servico.

## 6. Validacao funcional (UAT)

- [ ] Conferir KPIs do dashboard contra queries SQL de referencia.
- [ ] Executar `docs/queries/vendas/01_kpis_dash_vendas_r1.sql` para reconciliacao por periodo.
- [ ] Validar filtros e navegacao com usuario de negocio.
- [ ] Registrar evidencias (prints + queries + valores comparados).
- [ ] Ajustar divergencias e obter aprovacao final.

## 7. Go-live e consumo

- [ ] Publicar URL final do dashboard para os consumidores.
- [ ] Documentar instrucoes de acesso e uso (README rapido).
- [ ] Definir rotina de atualizacao (janela ETL + horario de consumo).
- [ ] Confirmar checklist de Go/No-Go assinado.

## 8. Operacao continua

- [ ] Monitorar disponibilidade do servico (`up/healthy`).
- [ ] Monitorar latencia de queries criticas.
- [ ] Definir procedimento de rollback (imagem anterior).
- [ ] Revisar backlog de evolucao (metas/descontos no dashboard R2).

---

## Criterio de pronto (DoD)

- [ ] Dashboard acessivel via URL em ambiente Docker.
- [ ] KPIs validados com SQL de referencia sem divergencia material.
- [ ] Usuario final consegue consumir o painel sem apoio tecnico continuo.
