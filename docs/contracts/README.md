# Contratos de Dados - Fase 0

Esta pasta armazena o contrato minimo de dados para integracao OLTP -> DW.
O objetivo e manter o processo simples, explicito e versionado em git.

## Escopo (Fase 0)

- Definir regras globais do contrato.
- Definir contratos de origem para entidades OLTP principais.
- Definir baseline de mapeamento OLTP -> DW.
- Definir regras minimas de qualidade de dados.

## Estrutura de Pastas

```text
docs/contracts/
|-- README.md
|-- 00_global.md
|-- oltp/
|   |-- core.customers.md
|   |-- core.products.md
|   |-- core.orders.md
|   |-- core.order_items.md
|   `-- core.sellers.md
|-- mapping/
|   `-- oltp_to_dw_mapping.csv
|-- quality/
|   `-- dq_rules.md
`-- templates/
    `-- entity_contract_template.md
```

## Fluxo de Atualizacao

1. Alterar schema de origem (`sql/oltp/...`) ou logica de ETL.
2. Atualizar o contrato da entidade impactada em `docs/contracts/oltp/`.
3. Atualizar `mapping/oltp_to_dw_mapping.csv` se o mapeamento de destino mudar.
4. Adicionar ou ajustar regra em `quality/dq_rules.md`, quando necessario.
5. Incluir a atualizacao no mesmo PR da mudanca tecnica.

## Regras Gerais

- Nao remover colunas dos contratos sem nota de migracao.
- Usar `updated_at + id` como baseline de extracao incremental.
- Manter timezone em UTC.
- Preferir evolucao aditiva (novas colunas anulaveis) em vez de quebra de contrato.
