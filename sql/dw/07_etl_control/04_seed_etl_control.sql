-- ========================================
-- SCRIPT: 04_seed_etl_control.sql
-- OBJETIVO: cadastrar entidades iniciais da carga incremental (fase 3)
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    THROW 50001, 'Tabela ctl.etl_control nao existe. Execute 02_create_etl_control.sql antes.', 1;
END;
GO

PRINT '========================================';
PRINT 'SEED INICIAL DA TABELA ctl.etl_control';
PRINT '========================================';

;WITH src AS
(
    SELECT *
    FROM
    (
        VALUES
            ('dim_regiao',   'core', 'regions',             'region_id',   'updated_at', 'dim', 'DIM_REGIAO',   10, 1),
            ('dim_equipe',   'core', 'teams',               'team_id',     'updated_at', 'dim', 'DIM_EQUIPE',   20, 1),
            ('dim_cliente',  'core', 'customers',           'customer_id', 'updated_at', 'dim', 'DIM_CLIENTE',  30, 1),
            ('dim_produto',  'core', 'products',            'product_id',  'updated_at', 'dim', 'DIM_PRODUTO',  40, 1),
            ('dim_desconto', 'core', 'discount_campaigns',  'discount_id', 'updated_at', 'dim', 'DIM_DESCONTO', 50, 1),
            ('dim_vendedor', 'core', 'sellers',             'seller_id',   'updated_at', 'dim', 'DIM_VENDEDOR', 60, 1)
    ) v (
        entity_name,
        source_schema,
        source_table,
        source_pk_column,
        source_watermark_column,
        target_schema,
        target_table,
        load_order,
        is_active
    )
)
MERGE ctl.etl_control AS tgt
USING src
    ON src.entity_name = tgt.entity_name
WHEN MATCHED THEN
    UPDATE SET
        tgt.source_schema = src.source_schema,
        tgt.source_table = src.source_table,
        tgt.source_pk_column = src.source_pk_column,
        tgt.source_watermark_column = src.source_watermark_column,
        tgt.target_schema = src.target_schema,
        tgt.target_table = src.target_table,
        tgt.load_order = src.load_order,
        tgt.is_active = src.is_active,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT
    (
        entity_name,
        source_schema,
        source_table,
        source_pk_column,
        source_watermark_column,
        target_schema,
        target_table,
        load_order,
        is_active
    )
    VALUES
    (
        src.entity_name,
        src.source_schema,
        src.source_table,
        src.source_pk_column,
        src.source_watermark_column,
        src.target_schema,
        src.target_table,
        src.load_order,
        src.is_active
    );
GO

SELECT
    entity_name,
    source_schema,
    source_table,
    source_pk_column,
    source_watermark_column,
    target_schema,
    target_table,
    load_order,
    is_active,
    watermark_updated_at,
    watermark_id
FROM ctl.etl_control
ORDER BY load_order, entity_name;
GO

