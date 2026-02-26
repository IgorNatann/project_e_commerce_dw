-- ========================================
-- SCRIPT: 03_create_audit_etl_tables.sql
-- OBJETIVO: criar tabelas de auditoria das execucoes ETL
-- ========================================

USE DW_ECOMMERCE;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo');
    PRINT 'Schema audit criado.';
END;
GO

IF OBJECT_ID('audit.etl_run', 'U') IS NULL
BEGIN
    CREATE TABLE audit.etl_run
    (
        run_id BIGINT IDENTITY(1,1) NOT NULL,
        entities_requested VARCHAR(500) NOT NULL,
        started_by VARCHAR(128) NOT NULL CONSTRAINT DF_audit_etl_run_started_by DEFAULT SUSER_SNAME(),
        started_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_etl_run_started_at DEFAULT SYSUTCDATETIME(),
        finished_at DATETIME2(0) NULL,
        status VARCHAR(20) NOT NULL CONSTRAINT DF_audit_etl_run_status DEFAULT ('running'),
        entities_succeeded INT NOT NULL CONSTRAINT DF_audit_etl_run_entities_succeeded DEFAULT (0),
        entities_failed INT NOT NULL CONSTRAINT DF_audit_etl_run_entities_failed DEFAULT (0),
        error_message VARCHAR(4000) NULL,
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_etl_run_created_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_audit_etl_run PRIMARY KEY CLUSTERED (run_id),
        CONSTRAINT CK_audit_etl_run_status CHECK (status IN ('running', 'success', 'failed', 'partial')),
        CONSTRAINT CK_audit_etl_run_counts CHECK (entities_succeeded >= 0 AND entities_failed >= 0)
    );

    PRINT 'Tabela audit.etl_run criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_run ja existe.';
END;
GO

IF OBJECT_ID('audit.etl_run_entity', 'U') IS NULL
BEGIN
    CREATE TABLE audit.etl_run_entity
    (
        run_entity_id BIGINT IDENTITY(1,1) NOT NULL,
        run_id BIGINT NOT NULL,
        entity_name VARCHAR(100) NOT NULL,
        entity_started_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_etl_run_entity_started_at DEFAULT SYSUTCDATETIME(),
        entity_finished_at DATETIME2(0) NULL,
        status VARCHAR(20) NOT NULL CONSTRAINT DF_audit_etl_run_entity_status DEFAULT ('running'),
        extracted_count INT NOT NULL CONSTRAINT DF_audit_etl_run_entity_extracted_count DEFAULT (0),
        upserted_count INT NOT NULL CONSTRAINT DF_audit_etl_run_entity_upserted_count DEFAULT (0),
        soft_deleted_count INT NOT NULL CONSTRAINT DF_audit_etl_run_entity_soft_deleted_count DEFAULT (0),
        watermark_from_updated_at DATETIME2(0) NULL,
        watermark_from_id BIGINT NULL,
        watermark_to_updated_at DATETIME2(0) NULL,
        watermark_to_id BIGINT NULL,
        error_message VARCHAR(4000) NULL,
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_etl_run_entity_created_at DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_audit_etl_run_entity_updated_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_audit_etl_run_entity PRIMARY KEY CLUSTERED (run_entity_id),
        CONSTRAINT FK_audit_etl_run_entity_run FOREIGN KEY (run_id) REFERENCES audit.etl_run(run_id),
        CONSTRAINT UQ_audit_etl_run_entity UNIQUE (run_id, entity_name),
        CONSTRAINT CK_audit_etl_run_entity_status CHECK (status IN ('running', 'success', 'failed')),
        CONSTRAINT CK_audit_etl_run_entity_counts CHECK (
            extracted_count >= 0 AND upserted_count >= 0 AND soft_deleted_count >= 0
        )
    );

    PRINT 'Tabela audit.etl_run_entity criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_run_entity ja existe.';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.etl_run')
      AND name = 'IX_audit_etl_run_started_at'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_audit_etl_run_started_at
        ON audit.etl_run (started_at DESC)
        INCLUDE (status, finished_at, entities_succeeded, entities_failed);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.etl_run_entity')
      AND name = 'IX_audit_etl_run_entity_run_id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_audit_etl_run_entity_run_id
        ON audit.etl_run_entity (run_id, entity_name)
        INCLUDE (status, extracted_count, upserted_count, watermark_to_updated_at, watermark_to_id);
END;
GO
