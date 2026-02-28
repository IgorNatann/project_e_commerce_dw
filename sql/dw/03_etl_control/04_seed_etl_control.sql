-- ========================================
-- SCRIPT: 04_seed_etl_control.sql
-- OBJETIVO: cadastrar entidades iniciais no controle ETL
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    RAISERROR('Tabela ctl.etl_control nao existe. Execute 02_create_etl_control.sql antes.', 16, 1);
    RETURN;
END;
GO

;WITH seed_entities AS
(
    SELECT *
    FROM (
        VALUES
            ('dim_cliente',  'core.customers',            'dim.DIM_CLIENTE',   'customer_id',            1000, 2),
            ('dim_produto',  'core.products',             'dim.DIM_PRODUTO',   'product_id',             1000, 2),
            ('dim_regiao',   'core.regions',              'dim.DIM_REGIAO',    'region_id',              1000, 2),
            ('dim_equipe',   'core.teams',                'dim.DIM_EQUIPE',    'team_id',                1000, 2),
            ('dim_vendedor', 'core.sellers',              'dim.DIM_VENDEDOR',  'seller_id',              1000, 2),
            ('dim_desconto', 'core.discount_campaigns',   'dim.DIM_DESCONTO',  'discount_id',            1000, 2),
            ('fact_vendas',  'core.order_items',          'fact.FACT_VENDAS',  'order_item_id',          5000, 2),
            ('fact_metas',   'core.seller_targets_monthly','fact.FACT_METAS',  'seller_target_id',       5000, 2),
            ('fact_descontos','core.order_item_discounts','fact.FACT_DESCONTOS','order_item_discount_id',5000, 2)
    ) AS x(entity_name, source_table, target_table, source_pk_column, batch_size, cutoff_minutes)
)
MERGE ctl.etl_control AS target
USING seed_entities AS source
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
        target.is_active = CASE WHEN source.entity_name = 'dim_cliente' THEN 1 ELSE 0 END,
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
        CASE WHEN source.entity_name = 'dim_cliente' THEN 1 ELSE 0 END,
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
ORDER BY entity_name;
GO
