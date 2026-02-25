# Contract - core.products

## Metadata

- Layer: OLTP
- Status: draft
- Main DW target: `dim.DIM_PRODUTO`

## Grain

One row = one product SKU.

## Keys

- Primary key: `product_id`
- Business key: `sku` (unique)

## Incremental

- Watermark: `updated_at`
- Tie-breaker: `product_id`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| product_id | BIGINT | no | PK unique |
| sku | VARCHAR(50) | no | business key unique |
| product_name | VARCHAR(200) | no | non-empty |
| category_name | VARCHAR(100) | no | non-empty |
| subcategory_name | VARCHAR(100) | yes | - |
| supplier_id | BIGINT | no | FK to supplier |
| supplier_name | VARCHAR(150) | no | denormalized helper allowed |
| cost_price | DECIMAL(15,2) | no | `>= 0` |
| list_price | DECIMAL(15,2) | no | `>= 0` |
| product_status | VARCHAR(20) | no | `Ativo/Inativo/Descontinuado` |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- no duplicate `sku`
- `cost_price` and `list_price` non-negative
- allowed values for `product_status`

## DW Mapping Notes

- `product_id` -> `produto_original_id`
- `sku` -> `codigo_sku`
- `product_name` -> `nome_produto`
- `cost_price` -> `preco_custo`
- `list_price` -> `preco_sugerido`
- `product_status` -> `situacao`
