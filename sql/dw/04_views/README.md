# DW - Views auxiliares

Catalogo de views analiticas no schema `dim` e script master de orquestracao.

## Arquivos

- `01_vw_calendario_completo.sql`
- `02_vw_produtos_ativos.sql`
- `03_vw_hierarquia_geografica.sql`
- `04_master_views.sql`
- `05_vw_descontos_ativos.sql`
- `06_vw_vendedores_ativos.sql`
- `07_vw_hierarquia_vendedores.sql`
- `08_dw_analise_equipe_vendedores.sql`
- `09_vw_equipes_ativas.sql`
- `10_vw_ranking_equipes_meta.sql`
- `11_vw_analise_regional_equipes.sql`
- `12_vw_dash_vendas_r1.sql`
- `13_vw_dash_metas_r1.sql`
- `14_vw_dash_descontos_r1.sql`

## Execucao

Script master (recomendado):

```sql
:r sql/dw/04_views/04_master_views.sql
```

Ou via `sqlcmd`:

```bash
sqlcmd -S localhost,1433 -U sa -P "<senha>" -d DW_ECOMMERCE -i sql/dw/04_views/04_master_views.sql
```

## Relacao com a stack Docker

A stack one-shot prioriza readiness de `dim_cliente` e controle ETL.
As views nao sao pre-requisito para o primeiro ciclo validado e podem ser aplicadas depois.

## Quando aplicar

- Antes de criar consultas analiticas em `docs/queries`.
- Antes de publicar dashboards de negocio alem do monitor ETL.
- As views `fact.VW_DASH_VENDAS_R1`, `fact.VW_DASH_METAS_R1` e `fact.VW_DASH_DESCONTOS_R1` sao a base certificada dos dashboards R1 de vendas, metas e descontos/ROI.
