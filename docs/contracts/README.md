# Data Contracts - Phase 0

This folder stores the minimum data contract for OLTP -> DW integration.
The goal is to keep the process simple, explicit, and versioned in git.

## Scope (Phase 0)

- Define global contract rules.
- Define source contracts for core OLTP entities.
- Define OLTP -> DW mapping baseline.
- Define minimum data quality rules.

## Folder Structure

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

## Update Workflow

1. Change source schema (`sql/oltp/...`) or ETL logic.
2. Update the impacted entity contract in `docs/contracts/oltp/`.
3. Update `mapping/oltp_to_dw_mapping.csv` if target mapping changed.
4. Add/adjust rule in `quality/dq_rules.md` if needed.
5. Include the change in the same PR.

## Rules

- Do not remove columns from contracts without migration note.
- Use `updated_at + id` as incremental extraction baseline.
- Keep timezone in UTC.
- Prefer additive evolution (new nullable columns) over breaking changes.
