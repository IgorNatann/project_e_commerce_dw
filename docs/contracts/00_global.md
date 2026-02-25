# Global Data Contract (Phase 0)

Version: `0.1.0`  
Status: `draft`  
Scope: `OLTP source contracts for DW_ECOMMERCE loads`

## 1. Time Standard

- All timestamps must be stored in UTC.
- Source contract fields:
  - `created_at` (required)
  - `updated_at` (required)
  - `deleted_at` (nullable, soft delete)

## 2. Incremental Extraction Standard

- Baseline watermark: `(updated_at, id)`.
- Sort order: `ORDER BY updated_at, id`.
- Pagination strategy: keyset pagination (no `OFFSET`).
- Safety cutoff: process rows where `updated_at <= now_utc - 5 minutes`.

## 3. Delete Policy

- OLTP uses soft delete (`deleted_at IS NOT NULL`).
- DW ingestion must treat soft-deleted rows as inactive (or equivalent business status).

## 4. Data Type Conventions

- Monetary fields: `DECIMAL(15,2)`.
- Quantity fields: integer types.
- Flags: `BIT` (0 or 1).
- Business status: constrained `VARCHAR`.

## 5. Quality Baseline

Minimum expectations for each source entity:

- Primary key uniqueness.
- Business key uniqueness (when applicable).
- Mandatory fields not null.
- Referential integrity with parent entities.
- `updated_at >= created_at`.

## 6. Breaking Change Policy

Breaking changes include:

- rename/remove source columns used by ETL;
- semantic change in existing fields;
- PK or business key changes.

Required action for breaking changes:

1. update contract file;
2. update mapping file;
3. provide migration note in PR description;
4. update ETL tests/checks.
