-- ========================================
-- SCRIPT: 02_create_etl_control.sql
-- OBJETIVO: criar tabela de controle incremental por entidade
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
BEGIN
    CREATE TABLE ctl.etl_control
    (
        entity_name VARCHAR(100) NOT NULL,
        source_table VARCHAR(200) NOT NULL,
        target_table VARCHAR(200) NOT NULL,
        source_pk_column VARCHAR(128) NOT NULL,
        watermark_updated_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_ctl_etl_control_watermark_updated_at DEFAULT ('1900-01-01'),
        watermark_id BIGINT NOT NULL
            CONSTRAINT DF_ctl_etl_control_watermark_id DEFAULT (0),
        cutoff_minutes INT NOT NULL
            CONSTRAINT DF_ctl_etl_control_cutoff_minutes DEFAULT (2),
        batch_size INT NOT NULL
            CONSTRAINT DF_ctl_etl_control_batch_size DEFAULT (1000),
        is_active BIT NOT NULL
            CONSTRAINT DF_ctl_etl_control_is_active DEFAULT (1),
        last_run_id BIGINT NULL,
        last_status VARCHAR(20) NULL,
        last_success_at DATETIME2(0) NULL,
        created_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_ctl_etl_control_created_at DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_ctl_etl_control_updated_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ctl_etl_control PRIMARY KEY CLUSTERED (entity_name),
        CONSTRAINT CK_ctl_etl_control_cutoff_minutes CHECK (cutoff_minutes BETWEEN 0 AND 1440),
        CONSTRAINT CK_ctl_etl_control_batch_size CHECK (batch_size BETWEEN 1 AND 100000),
        CONSTRAINT CK_ctl_etl_control_last_status CHECK (
            last_status IN ('success', 'failed', 'partial') OR last_status IS NULL
        )
    );

    PRINT 'Tabela ctl.etl_control criada.';
END
ELSE
BEGIN
    PRINT 'Tabela ctl.etl_control ja existe.';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('ctl.etl_control')
      AND name = 'IX_ctl_etl_control_active'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ctl_etl_control_active
        ON ctl.etl_control (is_active, entity_name)
        INCLUDE (watermark_updated_at, watermark_id, batch_size, cutoff_minutes);

    PRINT 'Indice IX_ctl_etl_control_active criado.';
END
ELSE
BEGIN
    PRINT 'Indice IX_ctl_etl_control_active ja existe.';
END;
GO
