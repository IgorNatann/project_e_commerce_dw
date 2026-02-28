-- ========================================
-- SCRIPT: 07_activate_dim_cliente_scope.sql
-- OBJETIVO: manter dim_cliente e dim_produto ativas no controle ETL
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    RAISERROR('Tabela ctl.etl_control nao existe. Execute o setup de controle ETL antes.', 16, 1);
    RETURN;
END;
GO

IF NOT EXISTS (SELECT 1 FROM ctl.etl_control WHERE entity_name = 'dim_cliente')
BEGIN
    INSERT INTO ctl.etl_control
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
        'dim_cliente',
        'core.customers',
        'dim.DIM_CLIENTE',
        'customer_id',
        '1900-01-01',
        0,
        0,
        1000,
        1,
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM ctl.etl_control WHERE entity_name = 'dim_produto')
BEGIN
    INSERT INTO ctl.etl_control
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
        'dim_produto',
        'core.products',
        'dim.DIM_PRODUTO',
        'product_id',
        '1900-01-01',
        0,
        2,
        1000,
        1,
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );
END;
GO

UPDATE ctl.etl_control
SET
    is_active = CASE WHEN entity_name IN ('dim_cliente', 'dim_produto') THEN 1 ELSE is_active END,
    source_table = CASE
        WHEN entity_name = 'dim_cliente' THEN 'core.customers'
        WHEN entity_name = 'dim_produto' THEN 'core.products'
        ELSE source_table
    END,
    target_table = CASE
        WHEN entity_name = 'dim_cliente' THEN 'dim.DIM_CLIENTE'
        WHEN entity_name = 'dim_produto' THEN 'dim.DIM_PRODUTO'
        ELSE target_table
    END,
    source_pk_column = CASE
        WHEN entity_name = 'dim_cliente' THEN 'customer_id'
        WHEN entity_name = 'dim_produto' THEN 'product_id'
        ELSE source_pk_column
    END,
    batch_size = CASE
        WHEN entity_name IN ('dim_cliente', 'dim_produto') THEN 1000
        ELSE batch_size
    END,
    cutoff_minutes = CASE
        WHEN entity_name = 'dim_cliente' THEN 0
        WHEN entity_name = 'dim_produto' THEN 2
        ELSE cutoff_minutes
    END,
    updated_at = SYSUTCDATETIME();
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
ORDER BY entity_name;
GO
