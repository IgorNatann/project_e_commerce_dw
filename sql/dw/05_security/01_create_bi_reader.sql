-- ========================================
-- SCRIPT: 01_create_bi_reader.sql
-- OBJETIVO: criar login/usuario de leitura para dashboards de negocio
-- USO:
--   sqlcmd -S <server> -d DW_ECOMMERCE -U sa -P <pwd> ^
--          -v BI_READER_PASSWORD="<senha>" ^
--          -i sql/dw/05_security/01_create_bi_reader.sql
-- ========================================

USE master;
GO

IF N'$(BI_READER_PASSWORD)' = N''
BEGIN
    RAISERROR('Informe BI_READER_PASSWORD via sqlcmd -v.', 16, 1);
    RETURN;
END;
GO

DECLARE @password NVARCHAR(256) = N'$(BI_READER_PASSWORD)';
DECLARE @sql NVARCHAR(MAX);

IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'bi_reader')
BEGIN
    SET @sql = N'CREATE LOGIN bi_reader WITH PASSWORD = N''' + REPLACE(@password, N'''', N'''''') + N''', CHECK_POLICY = ON;';
    EXEC (@sql);
END
ELSE
BEGIN
    SET @sql = N'ALTER LOGIN bi_reader WITH PASSWORD = N''' + REPLACE(@password, N'''', N'''''') + N''';';
    EXEC (@sql);
END;
GO

USE DW_ECOMMERCE;
GO

IF DATABASE_PRINCIPAL_ID(N'bi_reader') IS NULL
BEGIN
    CREATE USER bi_reader FOR LOGIN bi_reader;
END;
GO

GRANT SELECT ON SCHEMA::dim TO bi_reader;
GRANT SELECT ON SCHEMA::fact TO bi_reader;
GO

PRINT 'Login/usuario bi_reader configurado com perfil somente leitura.';
GO
