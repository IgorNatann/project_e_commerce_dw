# Fluxo Geral do ETL (Fase 3)

## Visao rapida

1. Abrir `run_id` em `audit.etl_run`.
2. Ler watermark atual da entidade em `ctl.etl_control`.
3. Extrair lote incremental no OLTP.
4. Transformar os dados em memoria.
5. Upsert na dimensao do DW.
6. Gravar metricas em `audit.etl_run_entity`.
7. Avancar watermark somente se sucesso.
8. Fechar `audit.etl_run` com status final.

## Regras importantes

- Watermark usa par `(updated_at, id)`.
- Ordenacao de extracao: `ORDER BY updated_at, id`.
- Cutoff: nao processar registros acima de `now_utc - cutoff_minutes`.
- Falha de entidade: nao avanca watermark.
- Reexecucao da mesma janela: nao pode duplicar (idempotencia).

## Status de execucao

- `running`: em andamento
- `success`: finalizou sem erro
- `failed`: erro bloqueante
- `partial`: parte executou, parte falhou

