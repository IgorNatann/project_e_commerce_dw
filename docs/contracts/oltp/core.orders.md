# Contract - core.orders

## Metadata

- Layer: OLTP
- Status: draft
- Main DW targets: `fact.FACT_VENDAS` (header context), `fact.FACT_DESCONTOS`

## Grain

One row = one sales order.

## Keys

- Primary key: `order_id`
- Business key: `order_number` (unique)

## Incremental

- Watermark: `updated_at`
- Tie-breaker: `order_id`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| order_id | BIGINT | no | PK unique |
| order_number | VARCHAR(50) | no | business key unique |
| customer_id | BIGINT | no | FK to customer |
| seller_id | BIGINT | yes | FK to seller |
| region_code | VARCHAR(20) | yes | maps to region dimension |
| order_status | VARCHAR(20) | no | controlled domain |
| order_date | DATETIME2 | no | business event time |
| payment_status | VARCHAR(20) | yes | optional in phase 0 |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- no duplicate `order_number`
- parent keys must exist (`customer_id`, `seller_id` when not null)
- `order_date` cannot be null

## DW Mapping Notes

- `order_number` -> `numero_pedido`
- `order_date` -> join with `DIM_DATA` for `data_id`
- status can define business inclusion/exclusion rules for facts
