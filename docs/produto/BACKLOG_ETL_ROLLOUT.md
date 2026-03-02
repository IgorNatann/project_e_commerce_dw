# Backlog ETL e Rollout

Data de referencia: 2026-03-02
Fonte de verdade do fechamento: `docs/produto/PLANO_FECHAMENTO_PORTFOLIO_MVP.md`

## Itens ja concluidos (historico)

1. `ETL dim_desconto falha no bootstrap atual`
- Impacto: `python/etl/run_etl.py --entity all` retorna `partial` por conflito com `CK_DIM_DESCONTO_tipo`.
- Evidencia: valor normalizado no ETL (`Promo??o Autom?tica`) nao bate com constraint (`Promocao Automatica` com acento correto).
- Acao:
  - corrigir normalizacao em `python/etl/entities/dim_desconto.py`;
  - validar `tipo_desconto`, `metodo_desconto` e `aplica_em` contra constraints DW;
  - executar carga full de `dim_desconto` e retestar `--entity all`.
- Status: concluido em 2026-02-28.

2. `Consolidar rollout padrao da stack no CI/manual runbook`
- Impacto: risco de ambiente subir com escopo diferente do esperado.
- Acao:
  - validar pipeline de subida com check automatizado de escopo ativo em `ctl.etl_control`;
  - adicionar validacao de tabelas obrigatorias (`dim_*` + `fact_vendas`) apos `sql-init`.
- Status: concluido em 2026-02-28.

3. `Implementar ETL de fact_metas`
- Impacto: lacuna funcional do escopo R1.
- Acao:
  - criar `entities/fact_metas.py`;
  - criar `extract_fact_metas.sql` e `upsert_fact_metas.sql`;
  - ativar entidade em rollout quando validada.
- Status: concluido em 2026-02-28.

4. `Implementar ETL de fact_descontos`
- Impacto: lacuna funcional do escopo R1.
- Acao:
  - criar `entities/fact_descontos.py`;
  - criar `extract_fact_descontos.sql` e `upsert_fact_descontos.sql`;
  - ativar entidade em rollout quando validada.
- Status: concluido em 2026-02-28.

5. `Suite minima de testes ETL`
- Impacto: regressao pode passar despercebida em bootstrap/carga.
- Acao:
  - smoke test por entidade implementada;
  - teste de contrato DW (colunas, constraints, chaves);
  - teste de idempotencia por watermark.
- Status: concluido em 2026-02-28.

## P0 - Critico (aberto)

1. `Concluir deploy de portfolio em ambiente externo`
- Impacto: sem publicacao externa, o projeto nao fecha como portfolio-ready.
- Acao:
  - publicar stack em ambiente acessivel externamente;
  - garantir que SQL Server nao fique exposto publicamente;
  - definir URLs finais dos dashboards;
  - validar healthcheck e restart policy no host alvo.
- Status: em andamento.

2. `Formalizar runbook de operacao, incidente e recuperacao`
- Impacto: operacao fica dependente de conhecimento tacito.
- Acao:
  - publicar runbook com rotina diaria, troubleshooting, rollback e recuperacao;
  - alinhar runbook com scripts de operacao em `docker/` e `scripts/`;
  - incluir checklist final de Go/No-Go.
- Status: pendente.

3. `Consolidar evidencias de operacao para aceite final`
- Impacto: sem evidencias recorrentes, o aceite final fica fragil.
- Acao:
  - registrar evidencias de 7 dias de operacao (ETL, monitoria e testes recorrentes);
  - consolidar resultado final do Go/No-Go;
  - atualizar `README.md` com links finais de portfolio.
- Status: pendente.

## P1 - Medio (evolucao continua)

1. `Hardening de bootstrap`
- Impacto: menor risco de falhas transientes no startup do SQL Server.
- Acao:
  - manter estrategia de retry de conexao por database;
  - acompanhar metricas de tempo medio de inicializacao.
- Status: em andamento.

2. `Evoluir observabilidade`
- Impacto: resposta a incidentes ainda pode melhorar.
- Acao:
  - detalhar metricas de falha por entidade/job;
  - ampliar taxonomia e historico de alertas.
- Status: em andamento.
