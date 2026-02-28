-- ========================================
-- SCRIPT: 04_server_audit_file_checks.sql
-- OBJETIVO: validar SQL Server Audit em arquivo
-- ========================================

USE master;
GO

PRINT '1) Auditoria de servidor';
SELECT
    sa.name,
    sa.type_desc,
    sa.is_state_enabled,
    sfa.log_file_path,
    sfa.log_file_name
FROM sys.server_audits AS sa
LEFT JOIN sys.server_file_audits AS sfa
    ON sfa.audit_id = sa.audit_id
WHERE sa.name = 'DW_SERVER_AUDIT';
GO

PRINT '2) Especificacao da auditoria';
SELECT
    sas.name AS audit_spec_name,
    sa.name AS audit_name,
    sas.is_state_enabled
FROM sys.server_audit_specifications AS sas
INNER JOIN sys.server_audits AS sa
    ON sa.audit_guid = sas.audit_guid
WHERE sas.name = 'DW_SERVER_AUDIT_SPEC';
GO

PRINT '3) Ultimos eventos de login no arquivo';
SELECT TOP (20)
    event_time,
    action_id,
    succeeded,
    session_server_principal_name,
    server_principal_name,
    client_ip
FROM sys.fn_get_audit_file('/var/opt/mssql/audit/*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIS', 'LGIF', 'LGO')
ORDER BY event_time DESC;
GO
