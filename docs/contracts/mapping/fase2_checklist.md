# Checklist Fase 2 - Mapeamento OLTP -> DW

Data de referencia: `2026-02-26`

## 1. Status por item do checklist

- [x] Mapear cada coluna OLTP para coluna DW (matriz de mapeamento).
  - Evidencia: `docs/contracts/mapping/oltp_to_dw_mapping.csv`.
- [x] Definir regras de transformacao (status, enums, texto, moeda).
  - Evidencia: `docs/contracts/mapping/transformation_rules.md`.
- [x] Definir regra de SCD por dimensao (R1 majoritariamente Type 1).
  - Evidencia: `docs/decisoes/01_decisoes_modelagem.md`.
- [x] Definir tratamento de chaves desconhecidas (`-1` / `N/A`) no DW.
  - Evidencia: `docs/contracts/00_global.md` secao 7.

## 2. O que ainda falta para encerrar operacionalmente a fase

- [ ] Validar a matriz com implementacao ETL (fase 3) e ajustar colunas derivadas onde necessario.
- [ ] Criar evidencias de teste de lookup com fallback `-1` em carga de fato.
- [ ] Promover contratos de `rascunho` para `ativo` apos homologacao da primeira carga incremental.

## 3. Observacoes

- O mapeamento contempla as tabelas OLTP core:
  - `core.customers`, `core.products`, `core.regions`, `core.teams`, `core.sellers`,
  - `core.discount_campaigns`, `core.orders`, `core.order_items`,
  - `core.order_item_discounts`, `core.seller_targets_monthly`, `core.suppliers`.
- Linhas `N/A` na matriz indicam campos fora do escopo R1 ou reservados para evolucao futura.
