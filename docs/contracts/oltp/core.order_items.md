# Contract - core.order_items

## Metadata

- Layer: OLTP
- Status: draft
- Main DW target: `fact.FACT_VENDAS`

## Grain

One row = one product item within one order.

## Keys

- Primary key: `order_item_id`
- Business key: `(order_id, item_number)` unique

## Incremental

- Watermark: `updated_at`
- Tie-breaker: `order_item_id`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| order_item_id | BIGINT | no | PK unique |
| order_id | BIGINT | no | FK to orders |
| item_number | INT | no | sequential per order |
| product_id | BIGINT | no | FK to products |
| quantity | INT | no | `> 0` |
| unit_price | DECIMAL(15,2) | no | `>= 0` |
| gross_amount | DECIMAL(15,2) | no | `>= 0` |
| discount_amount | DECIMAL(15,2) | no | `>= 0` |
| net_amount | DECIMAL(15,2) | no | `gross_amount - discount_amount` |
| return_quantity | INT | yes | `>= 0` |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- unique `(order_id, item_number)`
- no orphan `order_id` or `product_id`
- exact financial rule for net amount
- `return_quantity <= quantity` when present

## DW Mapping Notes

- one source row generally maps to one row in `FACT_VENDAS`
- `gross_amount` -> `valor_total_bruto`
- `discount_amount` -> `valor_total_descontos`
- `net_amount` -> `valor_total_liquido`
- return fields support devolucao metrics
