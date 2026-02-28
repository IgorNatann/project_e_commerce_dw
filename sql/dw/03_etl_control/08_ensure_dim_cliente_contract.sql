-- ========================================
-- SCRIPT: 08_ensure_dim_cliente_contract.sql
-- OBJETIVO: garantir contrato minimo da dim_cliente para o ETL incremental
-- ========================================

USE DW_ECOMMERCE;
GO

IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_CLIENTE nao existe. Execute 02_dim_cliente.sql antes.', 16, 1);
    RETURN;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'CK_DIM_CLIENTE_segmento'
)
BEGIN
    ALTER TABLE dim.DIM_CLIENTE
        DROP CONSTRAINT CK_DIM_CLIENTE_segmento;
END;
GO

UPDATE dim.DIM_CLIENTE
SET segmento = CASE
    WHEN UPPER(segmento) LIKE 'PESSOA%JUR%' THEN 'Pessoa Juridica'
    ELSE 'Pessoa Fisica'
END
WHERE segmento IS NULL
   OR segmento NOT IN ('Pessoa Fisica', 'Pessoa Juridica', 'Pessoa Física', 'Pessoa Jurídica');
GO

ALTER TABLE dim.DIM_CLIENTE
ADD CONSTRAINT CK_DIM_CLIENTE_segmento
CHECK
(
    segmento IN
    (
        'Pessoa Fisica',
        'Pessoa Juridica',
        'Pessoa Física',
        'Pessoa Jurídica'
    )
);
GO

ALTER TABLE dim.DIM_CLIENTE
CHECK CONSTRAINT CK_DIM_CLIENTE_segmento;
GO

PRINT 'Contrato da dim_cliente validado para o ETL.';
GO
