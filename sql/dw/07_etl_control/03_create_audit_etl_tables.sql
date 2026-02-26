-- ========================================
-- SCRIPT: 03_create_audit_etl_tables.sql
-- OBJETIVO: criar tabelas de auditoria da execucao ETL
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo');
END
GO

PRINT '========================================';
PRINT 'CRIACAO DE TABELAS audit.etl_*';
PRINT '========================================';

IF OBJECT_ID('audit.etl_run', 'U') IS NULL
BEGIN
    CREATE TABLE audit.etl_run
    (
        run_id UNIQUEIDENTIFIER NOT NULL
            DEFAULT NEWSEQUENTIALID(),
        pipeline_name VARCHAR(100) NOT NULL,
        run_mode VARCHAR(20) NOT NULL DEFAULT 'incremental',
        cutoff_utc DATETIME2(0) NOT NULL,
        started_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        finished_at DATETIME2(0) NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'running',
        requested_by VARCHAR(100) NULL,
        host_name VARCHAR(128) NULL,
        error_message NVARCHAR(4000) NULL,
        created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_audit_etl_run
            PRIMARY KEY CLUSTERED (run_id),
        CONSTRAINT CK_audit_etl_run_mode
            CHECK (run_mode IN ('full', 'incremental', 'reprocess')),
        CONSTRAINT CK_audit_etl_run_status
            CHECK (status IN ('running', 'success', 'failed', 'partial')),
        CONSTRAINT CK_audit_etl_run_time
            CHECK (finished_at IS NULL OR finished_at >= started_at)
    );

    PRINT 'Tabela audit.etl_run criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_run ja existe.';
END
GO

IF OBJECT_ID('audit.etl_run_entity', 'U') IS NULL
BEGIN
    CREATE TABLE audit.etl_run_entity
    (
        run_id UNIQUEIDENTIFIER NOT NULL,
        entity_name VARCHAR(100) NOT NULL,
        source_object VARCHAR(256) NULL,
        target_object VARCHAR(256) NULL,

        entity_started_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        entity_finished_at DATETIME2(0) NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'running',

        watermark_from_updated_at DATETIME2(0) NOT NULL,
        watermark_from_id BIGINT NOT NULL,
        watermark_to_updated_at DATETIME2(0) NULL,
        watermark_to_id BIGINT NULL,

        extracted_rows BIGINT NOT NULL DEFAULT 0,
        staged_rows BIGINT NOT NULL DEFAULT 0,
        inserted_rows BIGINT NOT NULL DEFAULT 0,
        updated_rows BIGINT NOT NULL DEFAULT 0,
        rejected_rows BIGINT NOT NULL DEFAULT 0,
        deleted_rows BIGINT NOT NULL DEFAULT 0,

        message NVARCHAR(2000) NULL,
        error_message NVARCHAR(4000) NULL,

        CONSTRAINT PK_audit_etl_run_entity
            PRIMARY KEY CLUSTERED (run_id, entity_name),
        CONSTRAINT FK_audit_etl_run_entity_run
            FOREIGN KEY (run_id)
            REFERENCES audit.etl_run(run_id),
        CONSTRAINT FK_audit_etl_run_entity_control
            FOREIGN KEY (entity_name)
            REFERENCES ctl.etl_control(entity_name),
        CONSTRAINT CK_audit_etl_run_entity_status
            CHECK (status IN ('running', 'success', 'failed', 'skipped')),
        CONSTRAINT CK_audit_etl_run_entity_time
            CHECK (entity_finished_at IS NULL OR entity_finished_at >= entity_started_at),
        CONSTRAINT CK_audit_etl_run_entity_from_id
            CHECK (watermark_from_id >= 0),
        CONSTRAINT CK_audit_etl_run_entity_to_id
            CHECK (watermark_to_id IS NULL OR watermark_to_id >= 0),
        CONSTRAINT CK_audit_etl_run_entity_to_pair
            CHECK (
                (watermark_to_updated_at IS NULL AND watermark_to_id IS NULL)
                OR
                (watermark_to_updated_at IS NOT NULL AND watermark_to_id IS NOT NULL)
            ),
        CONSTRAINT CK_audit_etl_run_entity_counts
            CHECK (
                extracted_rows >= 0
                AND staged_rows >= 0
                AND inserted_rows >= 0
                AND updated_rows >= 0
                AND rejected_rows >= 0
                AND deleted_rows >= 0
            )
    );

    PRINT 'Tabela audit.etl_run_entity criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_run_entity ja existe.';
END
GO

IF OBJECT_ID('audit.etl_rejects', 'U') IS NULL
BEGIN
    CREATE TABLE audit.etl_rejects
    (
        reject_id BIGINT IDENTITY(1,1) NOT NULL,
        run_id UNIQUEIDENTIFIER NOT NULL,
        entity_name VARCHAR(100) NOT NULL,
        source_pk VARCHAR(200) NULL,
        reason_code VARCHAR(80) NOT NULL,
        reason_detail NVARCHAR(2000) NULL,
        payload_json NVARCHAR(MAX) NULL,
        created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_audit_etl_rejects
            PRIMARY KEY CLUSTERED (reject_id),
        CONSTRAINT FK_audit_etl_rejects_run_entity
            FOREIGN KEY (run_id, entity_name)
            REFERENCES audit.etl_run_entity(run_id, entity_name),
        CONSTRAINT CK_audit_etl_rejects_payload_json
            CHECK (payload_json IS NULL OR ISJSON(payload_json) = 1)
    );

    PRINT 'Tabela audit.etl_rejects criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.etl_rejects ja existe.';
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.etl_run')
      AND name = 'IX_audit_etl_run_status_started'
)
BEGIN
    CREATE INDEX IX_audit_etl_run_status_started
        ON audit.etl_run (status, started_at DESC);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.etl_run_entity')
      AND name = 'IX_audit_etl_run_entity_entity_status'
)
BEGIN
    CREATE INDEX IX_audit_etl_run_entity_entity_status
        ON audit.etl_run_entity (entity_name, status, entity_started_at DESC);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.etl_rejects')
      AND name = 'IX_audit_etl_rejects_run_entity'
)
BEGIN
    CREATE INDEX IX_audit_etl_rejects_run_entity
        ON audit.etl_rejects (run_id, entity_name, created_at DESC);
END
GO

