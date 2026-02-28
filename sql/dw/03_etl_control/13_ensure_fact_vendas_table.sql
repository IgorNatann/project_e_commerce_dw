-- ========================================
-- SCRIPT: 13_ensure_fact_vendas_table.sql
-- OBJETIVO: garantir estrutura minima/idempotente da fact.FACT_VENDAS
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

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

IF OBJECT_ID('dim.DIM_REGIAO', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_REGIAO nao existe.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_VENDEDOR nao existe.', 16, 1);
    RETURN;
END;
GO

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
BEGIN
    CREATE TABLE fact.FACT_VENDAS
    (
        venda_id BIGINT IDENTITY(1,1) NOT NULL,
        venda_original_id BIGINT NOT NULL,

        data_id INT NOT NULL,
        cliente_id INT NOT NULL,
        produto_id INT NOT NULL,
        regiao_id INT NOT NULL,
        vendedor_id INT NULL,

        quantidade_vendida INT NOT NULL,
        preco_unitario_tabela DECIMAL(10,2) NOT NULL,
        valor_total_bruto DECIMAL(15,2) NOT NULL,
        valor_total_descontos DECIMAL(15,2) NOT NULL CONSTRAINT DF_FACT_VENDAS_valor_total_descontos DEFAULT 0,
        valor_total_liquido DECIMAL(15,2) NOT NULL,
        custo_total DECIMAL(15,2) NOT NULL,
        quantidade_devolvida INT NOT NULL CONSTRAINT DF_FACT_VENDAS_qtd_devolvida DEFAULT 0,
        valor_devolvido DECIMAL(15,2) NOT NULL CONSTRAINT DF_FACT_VENDAS_valor_devolvido DEFAULT 0,
        percentual_comissao DECIMAL(5,2) NULL,
        valor_comissao DECIMAL(15,2) NULL,
        numero_pedido VARCHAR(20) NOT NULL,
        teve_desconto BIT NOT NULL CONSTRAINT DF_FACT_VENDAS_teve_desconto DEFAULT 0,
        data_inclusao DATETIME NOT NULL CONSTRAINT DF_FACT_VENDAS_data_inclusao DEFAULT GETDATE(),
        data_atualizacao DATETIME NOT NULL CONSTRAINT DF_FACT_VENDAS_data_atualizacao DEFAULT GETDATE(),

        CONSTRAINT PK_FACT_VENDAS PRIMARY KEY CLUSTERED (venda_id),
        CONSTRAINT UK_FACT_VENDAS_original_id UNIQUE (venda_original_id),
        CONSTRAINT FK_FACT_VENDAS_data FOREIGN KEY (data_id) REFERENCES dim.DIM_DATA(data_id),
        CONSTRAINT FK_FACT_VENDAS_cliente FOREIGN KEY (cliente_id) REFERENCES dim.DIM_CLIENTE(cliente_id),
        CONSTRAINT FK_FACT_VENDAS_produto FOREIGN KEY (produto_id) REFERENCES dim.DIM_PRODUTO(produto_id),
        CONSTRAINT FK_FACT_VENDAS_regiao FOREIGN KEY (regiao_id) REFERENCES dim.DIM_REGIAO(regiao_id),
        CONSTRAINT FK_FACT_VENDAS_vendedor FOREIGN KEY (vendedor_id) REFERENCES dim.DIM_VENDEDOR(vendedor_id),
        CONSTRAINT CK_FACT_VENDAS_quantidade CHECK (quantidade_vendida > 0),
        CONSTRAINT CK_FACT_VENDAS_valores CHECK (
            valor_total_bruto >= 0 AND
            valor_total_descontos >= 0 AND
            valor_total_liquido >= 0 AND
            custo_total >= 0
        ),
        CONSTRAINT CK_FACT_VENDAS_devolucao CHECK (
            quantidade_devolvida >= 0 AND
            quantidade_devolvida <= quantidade_vendida
        )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_VENDAS')
      AND name = 'IX_FACT_VENDAS_data'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_data
        ON fact.FACT_VENDAS(data_id)
        INCLUDE (valor_total_liquido, quantidade_vendida);
END;
GO

PRINT 'Estrutura da fact.FACT_VENDAS garantida para o ETL incremental.';
GO
