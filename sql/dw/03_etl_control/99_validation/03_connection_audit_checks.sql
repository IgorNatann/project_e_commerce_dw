-- ========================================
-- SCRIPT: 03_connection_audit_checks.sql
-- OBJETIVO: validar auditoria de conexoes
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '1) Objetos de auditoria de conexao';
SELECT
    CASE WHEN OBJECT_ID('audit.connection_login_events', 'U') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS table_connection_login_events,
    CASE WHEN OBJECT_ID('audit.vw_connection_login_events_recent', 'V') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS view_connection_recent,
    CASE WHEN OBJECT_ID('audit.sp_connection_audit_cleanup', 'P') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS proc_cleanup,
    CASE WHEN OBJECT_ID('audit.sp_capture_connection_snapshot', 'P') IS NOT NULL THEN 'OK' ELSE 'PENDENTE' END AS proc_capture_snapshot;
GO

PRINT '2) Capturar snapshot atual';
EXEC audit.sp_capture_connection_snapshot;
GO

PRINT '3) Ultimos eventos de conexao';
SELECT TOP (20)
    connection_event_id,
    event_time_utc,
    login_name,
    host_name,
    program_name,
    client_net_address
FROM audit.connection_login_events
ORDER BY connection_event_id DESC;
GO
