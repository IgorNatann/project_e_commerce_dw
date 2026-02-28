-- ========================================
-- SCRIPT: 11_activate_fact_vendas_scope.sql
-- OBJETIVO: ativar fact_vendas no controle ETL incremental
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    RAISERROR('Tabela ctl.etl_control nao existe. Execute o setup de controle ETL antes.', 16, 1);
    RETURN;
END;
GO

;WITH source_row AS
(
    SELECT
        'fact_vendas' AS entity_name,
        'core.order_items' AS source_table,
        'fact.FACT_VENDAS' AS target_table,
        'order_item_id' AS source_pk_column,
        CAST(5000 AS INT) AS batch_size,
        CAST(2 AS INT) AS cutoff_minutes
)
MERGE ctl.etl_control AS target
USING source_row AS source
    ON target.entity_name = source.entity_name
WHEN MATCHED THEN
    UPDATE SET
        target.source_table = source.source_table,
        target.target_table = source.target_table,
        target.source_pk_column = source.source_pk_column,
        target.batch_size = CASE
            WHEN target.batch_size BETWEEN 1 AND 100000 THEN target.batch_size
            ELSE source.batch_size
        END,
        target.cutoff_minutes = CASE
            WHEN target.cutoff_minutes BETWEEN 0 AND 1440 THEN target.cutoff_minutes
            ELSE source.cutoff_minutes
        END,
        target.is_active = 1,
        target.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT
    (
        entity_name,
        source_table,
        target_table,
        source_pk_column,
        watermark_updated_at,
        watermark_id,
        cutoff_minutes,
        batch_size,
        is_active,
        created_at,
        updated_at
    )
    VALUES
    (
        source.entity_name,
        source.source_table,
        source.target_table,
        source.source_pk_column,
        '1900-01-01',
        0,
        source.cutoff_minutes,
        source.batch_size,
        1,
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );
GO

SELECT
    entity_name,
    source_table,
    target_table,
    source_pk_column,
    watermark_updated_at,
    watermark_id,
    batch_size,
    cutoff_minutes,
    is_active
FROM ctl.etl_control
WHERE entity_name = 'fact_vendas';
GO
