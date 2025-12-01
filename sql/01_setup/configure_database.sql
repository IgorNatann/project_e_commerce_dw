-- ========================================
-- SCRIPT: 03_configure_database.sql
-- DESCRIÇÃO: Configurações de otimização para DW
-- AUTOR: Seu Nome
-- DATA: 2024-12-01
-- PRÉ-REQUISITO: 02_create_schemas.sql
-- ========================================

USE master;
GO

PRINT '========================================';
PRINT 'CONFIGURAÇÕES DO DATABASE';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. MODELO DE RECUPERAÇÃO (SIMPLE)
-- ========================================
-- Data Warehouse não precisa de recuperação point-in-time
-- SIMPLE reduz overhead do log de transações

ALTER DATABASE DW_ECOMMERCE SET RECOVERY SIMPLE;
PRINT '✅ Modelo de recuperação: SIMPLE';

-- ========================================
-- 2. ESTATÍSTICAS AUTOMÁTICAS
-- ========================================
-- Importante para otimização de queries

ALTER DATABASE DW_ECOMMERCE SET AUTO_CREATE_STATISTICS ON;
PRINT '✅ Auto criação de estatísticas: HABILITADA';

ALTER DATABASE DW_ECOMMERCE SET AUTO_UPDATE_STATISTICS ON;
PRINT '✅ Auto atualização de estatísticas: HABILITADA';

ALTER DATABASE DW_ECOMMERCE SET AUTO_UPDATE_STATISTICS_ASYNC OFF;
PRINT '✅ Atualização assíncrona de estatísticas: DESABILITADA';

-- ========================================
-- 3. OTIMIZAÇÕES DE PERFORMANCE
-- ========================================

-- Page Verify para detecção de corrupção
ALTER DATABASE DW_ECOMMERCE SET PAGE_VERIFY CHECKSUM;
PRINT '✅ Page verify: CHECKSUM';

-- Modo de compatibilidade (ajuste conforme sua versão)
-- SQL Server 2019 = 150, 2022 = 160
ALTER DATABASE DW_ECOMMERCE SET COMPATIBILITY_LEVEL = 150;
PRINT '✅ Compatibility level: 150 (SQL Server 2019)';

-- Query Store (recomendado para DW)
ALTER DATABASE DW_ECOMMERCE SET QUERY_STORE = ON;
ALTER DATABASE DW_ECOMMERCE 
SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = AUTO
);
PRINT '✅ Query Store: HABILITADO';

-- ========================================
-- 4. CONFIGURAÇÕES DE ACESSO
-- ========================================

-- Multi-user (padrão)
ALTER DATABASE DW_ECOMMERCE SET MULTI_USER;
PRINT '✅ Modo de acesso: MULTI_USER';

-- Read/Write (padrão)
ALTER DATABASE DW_ECOMMERCE SET READ_WRITE;
PRINT '✅ Modo de leitura/escrita: READ_WRITE';

-- ========================================
-- 5. CONFIGURAÇÕES ESPECÍFICAS PARA DW
-- ========================================

USE DW_ECOMMERCE;
GO

-- Habilitar Database Scoped Configuration
-- Otimizações específicas do SQL Server 2016+

-- Legacy Cardinality Estimation (desabilitar - usar novo estimador)
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
PRINT '✅ Legacy Cardinality Estimation: DESABILITADO';

-- Parameter Sniffing (manter habilitado)
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = ON;
PRINT '✅ Parameter Sniffing: HABILITADO';

-- Query Optimizer Hotfixes (habilitar para ter últimas otimizações)
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON;
PRINT '✅ Query Optimizer Hotfixes: HABILITADO';

-- ========================================
-- 6. CRIAR EXTENDED PROPERTIES (Documentação)
-- ========================================

-- Adicionar descrição ao database
EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Data Warehouse dimensional para análise de e-commerce. Modelagem Kimball com 8 dimensões e 5 tabelas fato.';

EXEC sys.sp_addextendedproperty 
    @name = N'Author',
    @value = N'Seu Nome';

EXEC sys.sp_addextendedproperty 
    @name = N'Version',
    @value = N'1.0.0';

EXEC sys.sp_addextendedproperty 
    @name = N'Created',
    @value = N'2024-12-01';

PRINT '✅ Extended properties (documentação) adicionadas';

-- ========================================
-- 7. VALIDAÇÃO FINAL
-- ========================================
PRINT '';
PRINT '========================================';
PRINT 'VALIDAÇÃO DAS CONFIGURAÇÕES';
PRINT '========================================';

USE master;
GO

-- Exibir configurações aplicadas
SELECT 
    name AS [Database],
    recovery_model_desc AS [Recovery Model],
    page_verify_option_desc AS [Page Verify],
    is_auto_create_stats_on AS [Auto Create Stats],
    is_auto_update_stats_on AS [Auto Update Stats],
    is_query_store_on AS [Query Store],
    compatibility_level AS [Compatibility Level],
    collation_name AS [Collation]
FROM sys.databases
WHERE name = 'DW_ECOMMERCE';

PRINT '';
PRINT '✅ Configurações aplicadas com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'DATABASE PRONTO PARA USO!';
PRINT '========================================';
PRINT '';
PRINT 'PRÓXIMOS PASSOS:';
PRINT '1. Execute scripts em: sql/02_ddl/dimensions/';
PRINT '2. Execute scripts em: sql/02_ddl/facts/';
PRINT '========================================';
GO