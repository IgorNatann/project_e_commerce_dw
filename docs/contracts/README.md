# Contratos de dados (OLTP -> DW)

Esta pasta versiona o contrato de dados usado pela esteira ETL.

## Relacao com a nova infra Docker

A stack Docker (`docker/up_stack.ps1`) ja sobe um baseline funcional para `dim_cliente`.
Este baseline depende dos contratos desta pasta para manter consistencia entre:

- origem OLTP (`core.customers`)
- destino DW (`dim.DIM_CLIENTE`)
- regras de transformacao e qualidade

## Estrutura

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
|   |-- oltp_to_dw_mapping.csv
|   |-- transformation_rules.md
|   `-- fase2_checklist.md
|-- quality/
|   `-- dq_rules.md
`-- templates/
    `-- entity_contract_template.md
```

## Fluxo de atualizacao

1. Alterar schema SQL ou logica ETL.
2. Atualizar contrato da entidade impactada.
3. Atualizar mapeamento OLTP -> DW, se necessario.
4. Atualizar regra de qualidade, se necessario.
5. Commitar junto da mudanca tecnica.

## Regras base

- Nao remover coluna de contrato sem nota de migracao.
- Manter padrao incremental `updated_at + id`.
- Manter timestamps em UTC.
- Preferir evolucao aditiva para reduzir quebra de compatibilidade.

## Escopo atual

A validacao operacional esta focada em `dim_cliente`; proximas entidades seguem o mesmo padrao de contrato.
