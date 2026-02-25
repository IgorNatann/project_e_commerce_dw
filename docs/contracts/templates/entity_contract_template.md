# Entity Contract Template

## Metadata

- Entity:
- Layer:
- Owner:
- Status: draft | active | deprecated

## Grain

One row represents:

## Keys

- Primary key:
- Business key:

## Incremental

- Watermark column: `updated_at`
- Tie-breaker: `<pk_column>`
- Extraction order: `updated_at, <pk_column>`

## Required Columns

| Column | Type | Null | Rule |
|---|---|---|---|
| id | BIGINT | no | PK unique |
| created_at | DATETIME2 | no | UTC |
| updated_at | DATETIME2 | no | UTC, `>= created_at` |
| deleted_at | DATETIME2 | yes | soft delete |

## Data Quality Checks

- PK uniqueness
- mandatory columns not null
- timestamp consistency
- FK integrity (if applicable)

## DW Targets

- Target tables:
- Transformation notes:

## Change Log

- YYYY-MM-DD - change description
