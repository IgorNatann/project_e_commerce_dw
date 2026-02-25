# Contract - core.sellers

## Metadata

- Layer: OLTP
- Status: draft
- Main DW targets: `dim.DIM_VENDEDOR`, `dim.DIM_EQUIPE`

## Grain

One row = one seller.

## Keys

- Primary key: `seller_id`
- Business key: `seller_code` (unique)

## Incremental

- Watermark: `updated_at`
- Tie-breaker: `seller_id`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| seller_id | BIGINT | no | PK unique |
| seller_code | VARCHAR(50) | no | business key unique |
| seller_name | VARCHAR(200) | no | non-empty |
| team_id | BIGINT | yes | FK to team |
| team_name | VARCHAR(150) | yes | helper attribute |
| manager_seller_id | BIGINT | yes | self-reference allowed |
| monthly_goal_amount | DECIMAL(15,2) | yes | `>= 0` |
| seller_status | VARCHAR(20) | no | `Ativo/Inativo` |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- no duplicate `seller_code`
- allowed values for `seller_status`
- if `manager_seller_id` present, must exist in same table

## DW Mapping Notes

- seller attributes feed `DIM_VENDEDOR`
- team attributes feed/relate to `DIM_EQUIPE`
- `monthly_goal_amount` supports fact metas derivation
