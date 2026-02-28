-- ========================================
-- SCRIPT: 06_configure_server_audit_file.sql
-- OBJETIVO: habilitar SQL Server Audit em arquivo no volume persistente
-- ========================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'DW_SERVER_AUDIT')
BEGIN
    ALTER SERVER AUDIT [DW_SERVER_AUDIT] WITH (STATE = OFF);
    ALTER SERVER AUDIT [DW_SERVER_AUDIT]
        TO FILE
        (
            FILEPATH = N'/var/opt/mssql/audit/',
            MAXSIZE = 256 MB,
            MAX_ROLLOVER_FILES = 30,
            RESERVE_DISK_SPACE = OFF
        )
        WITH
        (
            QUEUE_DELAY = 1000,
            ON_FAILURE = CONTINUE
        );
END
ELSE
BEGIN
    CREATE SERVER AUDIT [DW_SERVER_AUDIT]
        TO FILE
        (
            FILEPATH = N'/var/opt/mssql/audit/',
            MAXSIZE = 256 MB,
            MAX_ROLLOVER_FILES = 30,
            RESERVE_DISK_SPACE = OFF
        )
        WITH
        (
            QUEUE_DELAY = 1000,
            ON_FAILURE = CONTINUE
        );
END;
GO

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'DW_SERVER_AUDIT_SPEC')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [DW_SERVER_AUDIT_SPEC] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [DW_SERVER_AUDIT_SPEC];
END;
GO

CREATE SERVER AUDIT SPECIFICATION [DW_SERVER_AUDIT_SPEC]
FOR SERVER AUDIT [DW_SERVER_AUDIT]
    ADD (FAILED_LOGIN_GROUP),
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (LOGOUT_GROUP);
GO

ALTER SERVER AUDIT [DW_SERVER_AUDIT] WITH (STATE = ON);
ALTER SERVER AUDIT SPECIFICATION [DW_SERVER_AUDIT_SPEC] WITH (STATE = ON);
GO

PRINT 'Server audit de login configurado em /var/opt/mssql/audit.';
GO
