# Contract - core.customers

## Metadata

- Layer: OLTP
- Status: draft
- Main DW target: `dim.DIM_CLIENTE`

## Grain

One row = one customer profile.

## Keys

- Primary key: `customer_id`
- Business key: `customer_code` (unique)

## Incremental

- Watermark: `updated_at`
- Tie-breaker: `customer_id`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| customer_id | BIGINT | no | PK unique |
| customer_code | VARCHAR(50) | no | business key unique |
| full_name | VARCHAR(200) | no | non-empty |
| email | VARCHAR(200) | yes | valid format when present |
| phone | VARCHAR(30) | yes | normalized format |
| birth_date | DATE | yes | `<= current_date` |
| city | VARCHAR(100) | yes | - |
| state | VARCHAR(2) | yes | BR UF pattern |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- no duplicate `customer_code`
- no null in `customer_id`, `customer_code`, `full_name`
- `updated_at >= created_at`

## DW Mapping Notes

- `customer_id` -> `cliente_original_id`
- `full_name` -> `nome_cliente`
- `email`, `phone`, city/state fields -> corresponding customer attributes
- `deleted_at IS NOT NULL` should map to inactive flag in DW
