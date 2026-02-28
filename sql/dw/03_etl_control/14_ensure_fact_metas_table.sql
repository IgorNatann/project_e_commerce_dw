-- ========================================
-- SCRIPT: 14_ensure_fact_metas_table.sql
-- OBJETIVO: garantir estrutura minima/idempotente da fact.FACT_METAS
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

IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NULL
BEGIN
    RAISERROR('Tabela dim.DIM_VENDEDOR nao existe.', 16, 1);
    RETURN;
END;
GO

IF OBJECT_ID('fact.FACT_METAS', 'U') IS NULL
BEGIN
    CREATE TABLE fact.FACT_METAS
    (
        meta_id BIGINT IDENTITY(1,1) NOT NULL,
        vendedor_id INT NOT NULL,
        data_id INT NOT NULL,
        valor_meta DECIMAL(15,2) NOT NULL,
        quantidade_meta INT NULL,
        valor_realizado DECIMAL(15,2) NOT NULL CONSTRAINT DF_FACT_METAS_valor_realizado DEFAULT 0,
        quantidade_realizada INT NOT NULL CONSTRAINT DF_FACT_METAS_quantidade_realizada DEFAULT 0,
        percentual_atingido DECIMAL(5,2) NOT NULL CONSTRAINT DF_FACT_METAS_percentual_atingido DEFAULT 0,
        gap_meta DECIMAL(15,2) NOT NULL CONSTRAINT DF_FACT_METAS_gap_meta DEFAULT 0,
        ticket_medio_realizado DECIMAL(10,2) NULL,
        ranking_periodo INT NULL,
        quartil_performance VARCHAR(10) NULL,
        meta_batida BIT NOT NULL CONSTRAINT DF_FACT_METAS_meta_batida DEFAULT 0,
        meta_superada BIT NOT NULL CONSTRAINT DF_FACT_METAS_meta_superada DEFAULT 0,
        eh_periodo_fechado BIT NOT NULL CONSTRAINT DF_FACT_METAS_eh_periodo_fechado DEFAULT 0,
        tipo_periodo VARCHAR(20) NOT NULL CONSTRAINT DF_FACT_METAS_tipo_periodo DEFAULT 'Mensal',
        observacoes VARCHAR(500) NULL,
        data_inclusao DATETIME NOT NULL CONSTRAINT DF_FACT_METAS_data_inclusao DEFAULT GETDATE(),
        data_ultima_atualizacao DATETIME NOT NULL CONSTRAINT DF_FACT_METAS_data_ultima_atualizacao DEFAULT GETDATE(),

        CONSTRAINT PK_FACT_METAS PRIMARY KEY CLUSTERED (meta_id),
        CONSTRAINT UK_FACT_METAS_vendedor_periodo UNIQUE (vendedor_id, data_id, tipo_periodo),
        CONSTRAINT FK_FACT_METAS_vendedor FOREIGN KEY (vendedor_id) REFERENCES dim.DIM_VENDEDOR(vendedor_id),
        CONSTRAINT FK_FACT_METAS_data FOREIGN KEY (data_id) REFERENCES dim.DIM_DATA(data_id),
        CONSTRAINT CK_FACT_METAS_valor_meta_positivo CHECK (valor_meta > 0),
        CONSTRAINT CK_FACT_METAS_quantidade_meta CHECK (quantidade_meta IS NULL OR quantidade_meta > 0),
        CONSTRAINT CK_FACT_METAS_valores_positivos CHECK (valor_realizado >= 0 AND quantidade_realizada >= 0),
        CONSTRAINT CK_FACT_METAS_percentual_valido CHECK (percentual_atingido >= 0),
        CONSTRAINT CK_FACT_METAS_tipo_periodo CHECK (tipo_periodo IN ('Mensal', 'Trimestral', 'Anual')),
        CONSTRAINT CK_FACT_METAS_quartil CHECK (quartil_performance IN ('Q1', 'Q2', 'Q3', 'Q4') OR quartil_performance IS NULL),
        CONSTRAINT CK_FACT_METAS_meta_batida_coerente CHECK (
            (meta_batida = 0 AND percentual_atingido < 100) OR
            (meta_batida = 1 AND percentual_atingido >= 100)
        )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_METAS')
      AND name = 'IX_FACT_METAS_vendedor_data'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_METAS_vendedor_data
        ON fact.FACT_METAS(vendedor_id, data_id)
        INCLUDE (valor_meta, valor_realizado, percentual_atingido, meta_batida, meta_superada);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact.FACT_METAS')
      AND name = 'IX_FACT_METAS_data'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FACT_METAS_data
        ON fact.FACT_METAS(data_id)
        INCLUDE (vendedor_id, valor_realizado, meta_batida);
END;
GO

PRINT 'Estrutura da fact.FACT_METAS garantida para o ETL incremental.';
GO
