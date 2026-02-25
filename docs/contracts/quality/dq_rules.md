# Data Quality Rules (Phase 0)

## Core Rule Set

1. PK uniqueness in every source table.
2. Business key uniqueness when defined.
3. Mandatory columns cannot be null.
4. Child rows cannot reference missing parent rows.
5. `updated_at` cannot be earlier than `created_at`.
6. Soft-deleted rows must keep business keys immutable.

## Financial Integrity Rules

For order item rows:

- `gross_amount >= 0`
- `discount_amount >= 0`
- `net_amount = gross_amount - discount_amount`
- `quantity > 0`
- `unit_price >= 0`

## Operational Freshness Rules

- Incremental run should not process rows newer than cutoff (`now_utc - 5 minutes`).
- Every incremental batch must report:
  - extracted rows
  - loaded rows
  - rejected rows

## Reconciliation Rules (OLTP vs DW)

- row count by period
- sum(gross), sum(discount), sum(net) by period
- distinct order count by period

Tolerance for aggregates in Phase 0: exact match (0 difference).
