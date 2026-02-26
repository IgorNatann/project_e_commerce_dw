-- ========================================
-- SCRIPT: 02_create_etl_control.sql
-- OBJETIVO: criar tabela de controle de watermark por entidade
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
BEGIN
    EXEC('CREATE SCHEMA ctl AUTHORIZATION dbo');
END
GO

PRINT '========================================';
PRINT 'CRIACAO DA TABELA ctl.etl_control';
PRINT '========================================';

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    CREATE TABLE ctl.etl_control
    (
        entity_name VARCHAR(100) NOT NULL,
        source_schema SYSNAME NOT NULL,
        source_table SYSNAME NOT NULL,
        source_pk_column SYSNAME NOT NULL,
        source_watermark_column SYSNAME NOT NULL DEFAULT 'updated_at',
        target_schema SYSNAME NOT NULL,
        target_table SYSNAME NOT NULL,
        load_order INT NOT NULL DEFAULT 100,
        is_active BIT NOT NULL DEFAULT 1,

        watermark_updated_at DATETIME2(0) NOT NULL
            DEFAULT CAST('19000101' AS DATETIME2(0)),
        watermark_id BIGINT NOT NULL DEFAULT 0,

        last_success_run_id UNIQUEIDENTIFIER NULL,
        last_success_at DATETIME2(0) NULL,

        created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_ctl_etl_control
            PRIMARY KEY CLUSTERED (entity_name),
        CONSTRAINT UQ_ctl_etl_control_source
            UNIQUE (source_schema, source_table),
        CONSTRAINT CK_ctl_etl_control_load_order
            CHECK (load_order > 0),
        CONSTRAINT CK_ctl_etl_control_watermark_id
            CHECK (watermark_id >= 0),
        CONSTRAINT CK_ctl_etl_control_time
            CHECK (updated_at >= created_at)
    );

    PRINT 'Tabela ctl.etl_control criada.';
END
ELSE
BEGIN
    PRINT 'Tabela ctl.etl_control ja existe.';
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('ctl.etl_control')
      AND name = 'IX_ctl_etl_control_active_order'
)
BEGIN
    CREATE INDEX IX_ctl_etl_control_active_order
        ON ctl.etl_control (is_active, load_order, entity_name);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('ctl.etl_control')
      AND name = 'IX_ctl_etl_control_target'
)
BEGIN
    CREATE INDEX IX_ctl_etl_control_target
        ON ctl.etl_control (target_schema, target_table);
END
GO

SELECT
    c.name AS column_name,
    t.name AS type_name,
    c.max_length,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t
    ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('ctl.etl_control')
ORDER BY c.column_id;
GO

