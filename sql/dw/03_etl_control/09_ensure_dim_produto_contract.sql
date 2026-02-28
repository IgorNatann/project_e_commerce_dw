-- ========================================
-- SCRIPT: 09_ensure_dim_produto_contract.sql
-- OBJETIVO: garantir contrato minimo da dim_produto para ETL incremental
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_PRODUTO nao existe. Execute 03_dim_produto.sql antes.', 16, 1);
    RETURN;
END;
GO

DECLARE @missing_columns TABLE (column_name SYSNAME NOT NULL);

INSERT INTO @missing_columns (column_name)
SELECT v.column_name
FROM (
    VALUES
        ('produto_original_id'),
        ('codigo_sku'),
        ('nome_produto'),
        ('categoria'),
        ('subcategoria'),
        ('marca'),
        ('fornecedor_id'),
        ('nome_fornecedor'),
        ('preco_custo'),
        ('preco_sugerido'),
        ('situacao'),
        ('data_cadastro'),
        ('data_ultima_atualizacao'),
        ('total_avaliacoes')
) AS v(column_name)
WHERE COL_LENGTH('dim.DIM_PRODUTO', v.column_name) IS NULL;

IF EXISTS (SELECT 1 FROM @missing_columns)
BEGIN
    DECLARE @missing_list NVARCHAR(MAX);
    SELECT @missing_list = STRING_AGG(column_name, ', ') FROM @missing_columns;
    RAISERROR('dim.DIM_PRODUTO sem colunas obrigatorias: %s', 16, 1, @missing_list);
    RETURN;
END;
GO

UPDATE dim.DIM_PRODUTO
SET situacao =
    CASE
        WHEN situacao IN ('Ativo', 'Inativo', 'Descontinuado') THEN situacao
        WHEN situacao IS NULL OR LTRIM(RTRIM(situacao)) = '' THEN 'Ativo'
        ELSE 'Ativo'
    END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'CK_DIM_PRODUTO_situacao'
)
BEGIN
    ALTER TABLE dim.DIM_PRODUTO
    WITH CHECK CHECK CONSTRAINT CK_DIM_PRODUTO_situacao;
END;
GO

PRINT 'Contrato da dim_produto validado para o ETL.';
GO
