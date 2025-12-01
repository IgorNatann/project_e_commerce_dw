-- ========================================
-- FASE 1: SETUP DO DATABASE
-- Data Warehouse E-commerce
-- ========================================

USE master;
GO

-- 1) Dropar se ja existir (CUIDADO: apaga tudo!)
IF DB_ID('DW_ECOMMERCE') IS NOT NULL
BEGIN
    ALTER DATABASE DW_ECOMMERCE SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DW_ECOMMERCE;
END;
GO

-- 2) Criar database usando caminhos padrao da instancia
DECLARE 
    @data_path NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)),
    @log_path  NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260)),
    @sql       NVARCHAR(MAX);

-- Fallback: usa caminho do master se as propriedades nao estiverem definidas
IF @data_path IS NULL
BEGIN
    SELECT TOP 1 @data_path = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM master.sys.database_files
    WHERE type = 0; -- data file
END;

IF @log_path IS NULL
BEGIN
    SELECT TOP 1 @log_path = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM master.sys.database_files
    WHERE type = 1; -- log file
END;

IF RIGHT(@data_path, 1) <> '\' SET @data_path = @data_path + '\';
IF RIGHT(@log_path, 1) <> '\' SET @log_path = @log_path + '\';

SET @sql = N'
CREATE DATABASE DW_ECOMMERCE
ON PRIMARY 
(
    NAME = N''DW_ECOMMERCE_Data'',
    FILENAME = N''' + @data_path + N'DW_ECOMMERCE_Data.mdf'',
    SIZE = 100MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 50MB
)
LOG ON 
(
    NAME = N''DW_ECOMMERCE_Log'',
    FILENAME = N''' + @log_path + N'DW_ECOMMERCE_Log.ldf'',
    SIZE = 50MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 25MB
);';

EXEC(@sql);
GO

-- 3) Configuracoes de performance para DW
ALTER DATABASE DW_ECOMMERCE SET RECOVERY SIMPLE; -- Menos overhead de log
ALTER DATABASE DW_ECOMMERCE SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE DW_ECOMMERCE SET AUTO_UPDATE_STATISTICS ON;
GO

-- 4) Usar o database recem-criado
USE DW_ECOMMERCE;
GO

PRINT 'Database DW_ECOMMERCE criado com sucesso!';
GO

-- ========================================
-- 2. CRIAR SCHEMAS
-- ========================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim')  EXEC('CREATE SCHEMA dim');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact') EXEC('CREATE SCHEMA fact');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')  EXEC('CREATE SCHEMA stg');
GO

PRINT 'Schemas criados: dim, fact, stg';
GO


