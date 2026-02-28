-- ========================================
-- SCRIPT: 15_ensure_fact_descontos_table.sql
-- OBJETIVO: garantir estrutura minima/idempotente da fact.FACT_DESCONTOS
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('dim.DIM_DESCONTO', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_DESCONTO nao existe.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
BEGIN
    RAISERROR('Tabela fact.FACT_VENDAS nao existe.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dim.DIM_DATA', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_DATA nao existe.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_CLIENTE nao existe.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_PRODUTO nao existe.', 16, 1);
    RETURN;
END;
GO

IF OBJECT_ID('fact.FACT_DESCONTOS', 'U') IS NULL
BEGIN
    CREATE TABLE fact.FACT_DESCONTOS
    (
        desconto_aplicado_id BIGINT IDENTITY(1,1) NOT NULL,
        desconto_aplicado_original_id BIGINT NOT NULL,
        desconto_id INT NOT NULL,
        venda_id BIGINT NOT NULL,
        data_aplicacao_id INT NOT NULL,
        cliente_id INT NOT NULL,
        produto_id INT NULL,
        nivel_aplicacao VARCHAR(30) NOT NULL,
        valor_desconto_aplicado DECIMAL(15,2) NOT NULL,
        valor_sem_desconto DECIMAL(15,2) NOT NULL,
        valor_com_desconto DECIMAL(15,2) NOT NULL,
        margem_antes_desconto DECIMAL(15,2) NULL,
        margem_apos_desconto DECIMAL(15,2) NULL,
        impacto_margem DECIMAL(15,2) NULL,
        percentual_desconto_efetivo DECIMAL(5,2) NOT NULL,
        desconto_aprovado BIT NOT NULL CONSTRAINT DF_FACT_DESCONTOS_desconto_aprovado DEFAULT 1,
        motivo_rejeicao VARCHAR(200) NULL,
        numero_pedido VARCHAR(20) NOT NULL,
        data_inclusao DATETIME NOT NULL CONSTRAINT DF_FACT_DESCONTOS_data_inclusao DEFAULT GETDATE(),
        data_atualizacao DATETIME NOT NULL CONSTRAINT DF_FACT_DESCONTOS_data_atualizacao DEFAULT GETDATE(),

        CONSTRAINT PK_FACT_DESCONTOS PRIMARY KEY CLUSTERED (desconto_aplicado_id),
        CONSTRAINT UK_FACT_DESCONTOS_original_id UNIQUE (desconto_aplicado_original_id),
        CONSTRAINT FK_FACT_DESCONTOS_desconto FOREIGN KEY (desconto_id) REFERENCES dim.DIM_DESCONTO(desconto_id),
        CONSTRAINT FK_FACT_DESCONTOS_venda FOREIGN KEY (venda_id) REFERENCES fact.FACT_VENDAS(venda_id),
        CONSTRAINT FK_FACT_DESCONTOS_data FOREIGN KEY (data_aplicacao_id) REFERENCES dim.DIM_DATA(data_id),
        CONSTRAINT FK_FACT_DESCONTOS_cliente FOREIGN KEY (cliente_id) REFERENCES dim.DIM_CLIENTE(cliente_id),
        CONSTRAINT FK_FACT_DESCONTOS_produto FOREIGN KEY (produto_id) REFERENCES dim.DIM_PRODUTO(produto_id),
        CONSTRAINT CK_FACT_DESCONTOS_valores_positivos CHECK (
            valor_desconto_aplicado >= 0
            AND valor_sem_desconto >= 0
            AND valor_com_desconto >= 0
        ),
        CONSTRAINT CK_FACT_DESCONTOS_valor_coerente CHECK (
            valor_com_desconto = valor_sem_desconto - valor_desconto_aplicado
        ),
        CONSTRAINT CK_FACT_DESCONTOS_percentual_valido CHECK (
            percentual_desconto_efetivo BETWEEN 0 AND 100
        ),
        CONSTRAINT CK_FACT_DESCONTOS_nivel_valido CHECK (
            nivel_aplicacao IN ('Item', 'Pedido', 'Frete', 'Categoria')
        )
    );
END;
GO

IF COL_LENGTH('fact.FACT_DESCONTOS', 'desconto_aplicado_original_id') IS NULL
BEGIN
    ALTER TABLE fact.FACT_DESCONTOS
    ADD desconto_aplicado_original_id BIGINT NULL;
END;
GO

IF COL_LENGTH('fact.FACT_DESCONTOS', 'desconto_aplicado_original_id') IS NOT NULL
BEGIN
    UPDATE fact.FACT_DESCONTOS
    SET desconto_aplicado_original_id = desconto_aplicado_id
    WHERE desconto_aplicado_original_id IS NULL;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('fact.FACT_DESCONTOS')
      AND name = 'desconto_aplicado_original_id'
      AND is_nullable = 1
)
BEGIN
    ALTER TABLE fact.FACT_DESCONTOS
    ALTER COLUMN desconto_aplicado_original_id BIGINT NOT NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID('fact.FACT_DESCONTOS')
      AND name = 'UK_FACT_DESCONTOS_original_id'
      AND type = 'UQ'
)
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM fact.FACT_DESCONTOS
        GROUP BY desconto_aplicado_original_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Nao foi possivel criar UK_FACT_DESCONTOS_original_id: existem chaves duplicadas.', 16, 1);
        RETURN;
    END;

    ALTER TABLE fact.FACT_DESCONTOS
    ADD CONSTRAINT UK_FACT_DESCONTOS_original_id UNIQUE (desconto_aplicado_original_id);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_DESCONTOS')
      AND name = 'IX_FACT_DESCONTOS_data'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_data
        ON fact.FACT_DESCONTOS(data_aplicacao_id)
        INCLUDE (desconto_id, valor_desconto_aplicado, valor_com_desconto);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_DESCONTOS')
      AND name = 'IX_FACT_DESCONTOS_venda'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_venda
        ON fact.FACT_DESCONTOS(venda_id)
        INCLUDE (desconto_id, valor_desconto_aplicado, percentual_desconto_efetivo);
END;
GO

PRINT 'Estrutura da fact.FACT_DESCONTOS garantida para o ETL incremental.';
GO
