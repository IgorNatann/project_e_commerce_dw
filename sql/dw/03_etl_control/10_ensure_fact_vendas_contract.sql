-- ========================================
-- SCRIPT: 10_ensure_fact_vendas_contract.sql
-- OBJETIVO: garantir contrato minimo da fact_vendas para ETL incremental
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
BEGIN
    RAISERROR('Tabela fact.FACT_VENDAS nao existe. Execute 01_fact_vendas.sql antes.', 16, 1);
    RETURN;
END;
GO

IF COL_LENGTH('fact.FACT_VENDAS', 'venda_original_id') IS NULL
BEGIN
    ALTER TABLE fact.FACT_VENDAS
        ADD venda_original_id BIGINT NULL;
END;
GO

UPDATE fact.FACT_VENDAS
SET venda_original_id = -venda_id
WHERE venda_original_id IS NULL;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('fact.FACT_VENDAS')
      AND name = 'venda_original_id'
      AND is_nullable = 1
)
BEGIN
    ALTER TABLE fact.FACT_VENDAS
        ALTER COLUMN venda_original_id BIGINT NOT NULL;
END;
GO

IF EXISTS
(
    SELECT venda_original_id
    FROM fact.FACT_VENDAS
    GROUP BY venda_original_id
    HAVING COUNT(*) > 1
)
BEGIN
    RAISERROR('fact.FACT_VENDAS possui duplicidade em venda_original_id.', 16, 1);
    RETURN;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID('fact.FACT_VENDAS')
      AND name = 'UK_FACT_VENDAS_original_id'
)
BEGIN
    ALTER TABLE fact.FACT_VENDAS
        ADD CONSTRAINT UK_FACT_VENDAS_original_id UNIQUE (venda_original_id);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_VENDAS')
      AND name = 'IX_FACT_VENDAS_original_id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_original_id
        ON fact.FACT_VENDAS(venda_original_id)
        INCLUDE (data_id, cliente_id, produto_id, data_atualizacao);
END;
GO

IF DATABASE_PRINCIPAL_ID('etl_monitor') IS NOT NULL
BEGIN
    BEGIN TRY
        GRANT SELECT ON SCHEMA::fact TO etl_monitor;
    END TRY
    BEGIN CATCH
    END CATCH;

    BEGIN TRY
        GRANT INSERT, UPDATE ON OBJECT::fact.FACT_VENDAS TO etl_monitor;
    END TRY
    BEGIN CATCH
    END CATCH;
END;
GO

PRINT 'Contrato da fact_vendas validado para o ETL.';
GO
