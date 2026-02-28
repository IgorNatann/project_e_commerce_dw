# Backlog ETL e Rollout

Data de referencia: 2026-02-28

## P0 - Critico

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

## P1 - Alto

1. `Implementar ETL de fact_metas`
- Impacto: lacuna funcional do escopo R1.
- Acao:
  - criar `entities/fact_metas.py`;
  - criar `extract_fact_metas.sql` e `upsert_fact_metas.sql`;
  - ativar entidade em rollout quando validada.
- Status: concluido em 2026-02-28.

2. `Implementar ETL de fact_descontos`
- Impacto: lacuna funcional do escopo R1.
- Acao:
  - criar `entities/fact_descontos.py`;
  - criar `extract_fact_descontos.sql` e `upsert_fact_descontos.sql`;
  - ativar entidade em rollout quando validada.
- Status: concluido em 2026-02-28.

3. `Suite minima de testes ETL`
- Impacto: regressao pode passar despercebida em bootstrap/carga.
- Acao:
  - smoke test por entidade implementada;
  - teste de contrato DW (colunas, constraints, chaves);
  - teste de idempotencia por watermark.
- Status: pendente.

## P2 - Medio

1. `Ajustar documentacao de operacao`
- Impacto: onboarding e troubleshooting mais lentos.
- Acao:
  - documentar diferenca entre scripts legados de rollout (`07`, `11`) e rollout atual (`12`, `13`);
  - incluir fluxo de recuperacao quando `sql-init` falhar.
- Status: em andamento.

2. `Hardening de bootstrap`
- Impacto: menor risco de falhas transientes no startup do SQL Server.
- Acao:
  - manter estrategia de retry de conexao por database;
  - avaliar metricas de tempo medio de inicializacao.
- Status: em andamento.
