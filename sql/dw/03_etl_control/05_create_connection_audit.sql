-- ========================================
-- SCRIPT: 05_create_connection_audit.sql
-- OBJETIVO: auditoria de conexoes SQL Server (snapshot seguro via DMV)
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('audit.connection_login_events', 'U') IS NULL
BEGIN
    CREATE TABLE audit.connection_login_events
    (
        connection_event_id BIGINT IDENTITY(1,1) NOT NULL,
        event_time_utc DATETIME2(3) NOT NULL CONSTRAINT DF_audit_conn_event_time DEFAULT SYSUTCDATETIME(),
        captured_by NVARCHAR(50) NOT NULL CONSTRAINT DF_audit_conn_captured_by DEFAULT ('SNAPSHOT_DMV'),
        session_id SMALLINT NULL,
        login_name SYSNAME NULL,
        host_name NVARCHAR(128) NULL,
        program_name NVARCHAR(256) NULL,
        database_name SYSNAME NULL,
        status NVARCHAR(30) NULL,
        login_time DATETIME NULL,
        net_transport NVARCHAR(40) NULL,
        protocol_type NVARCHAR(40) NULL,
        client_net_address VARCHAR(48) NULL,
        client_tcp_port INT NULL,
        encrypt_option NVARCHAR(10) NULL,
        auth_scheme NVARCHAR(60) NULL,
        CONSTRAINT PK_audit_connection_login_events PRIMARY KEY CLUSTERED (connection_event_id)
    );

    PRINT 'Tabela audit.connection_login_events criada.';
END
ELSE
BEGIN
    PRINT 'Tabela audit.connection_login_events ja existe.';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('audit.connection_login_events')
      AND name = 'IX_audit_connection_login_events_time'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_audit_connection_login_events_time
        ON audit.connection_login_events (event_time_utc DESC)
        INCLUDE (login_name, client_net_address, program_name, host_name, database_name);

    PRINT 'Indice IX_audit_connection_login_events_time criado.';
END;
GO

CREATE OR ALTER PROCEDURE audit.sp_capture_connection_snapshot
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit.connection_login_events
    (
        event_time_utc,
        captured_by,
        session_id,
        login_name,
        host_name,
        program_name,
        database_name,
        status,
        login_time,
        net_transport,
        protocol_type,
        client_net_address,
        client_tcp_port,
        encrypt_option,
        auth_scheme
    )
    SELECT
        SYSUTCDATETIME(),
        N'SNAPSHOT_DMV',
        s.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(s.database_id),
        s.status,
        s.login_time,
        c.net_transport,
        c.protocol_type,
        c.client_net_address,
        c.client_tcp_port,
        c.encrypt_option,
        c.auth_scheme
    FROM sys.dm_exec_sessions AS s
    LEFT JOIN sys.dm_exec_connections AS c
        ON c.session_id = s.session_id
    WHERE s.is_user_process = 1;
END;
GO

CREATE OR ALTER PROCEDURE audit.sp_connection_audit_cleanup
    @retention_days INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    IF @retention_days < 1
        SET @retention_days = 1;

    DELETE FROM audit.connection_login_events
    WHERE event_time_utc < DATEADD(DAY, -@retention_days, SYSUTCDATETIME());
END;
GO

CREATE OR ALTER VIEW audit.vw_connection_login_events_recent
AS
SELECT TOP (1000)
    connection_event_id,
    event_time_utc,
    captured_by,
    session_id,
    login_name,
    host_name,
    program_name,
    database_name,
    status,
    login_time,
    net_transport,
    protocol_type,
    client_net_address,
    client_tcp_port,
    encrypt_option,
    auth_scheme
FROM audit.connection_login_events
ORDER BY connection_event_id DESC;
GO

EXEC audit.sp_capture_connection_snapshot;
GO
