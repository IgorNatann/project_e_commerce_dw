-- ========================================
-- SCRIPT: 02_dim_cliente.sql
-- OBJETIVO: criar/garantir estrutura da dim.DIM_CLIENTE (idempotente)
-- NOTA: nao remove dados existentes
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'DIM_CLIENTE - CREATE/ENSURE (IDEMPOTENTE)';
PRINT '========================================';
PRINT '';
GO

IF SCHEMA_ID('dim') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA dim');
END;
GO

IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NULL
BEGIN
    PRINT 'Criando tabela dim.DIM_CLIENTE...';

    CREATE TABLE dim.DIM_CLIENTE
    (
        cliente_id INT IDENTITY(1,1) NOT NULL,
        cliente_original_id INT NOT NULL,

        nome_cliente VARCHAR(100) NOT NULL,
        email VARCHAR(100) NULL,
        telefone VARCHAR(20) NULL,
        cpf_cnpj VARCHAR(18) NULL,
        data_nascimento DATE NULL,
        genero CHAR(1) NULL,

        tipo_cliente VARCHAR(20) NOT NULL,
        segmento VARCHAR(20) NOT NULL,
        score_credito INT NULL,
        categoria_valor VARCHAR(20) NULL,

        endereco_completo VARCHAR(200) NULL,
        numero VARCHAR(10) NULL,
        complemento VARCHAR(50) NULL,
        bairro VARCHAR(50) NULL,
        cidade VARCHAR(100) NOT NULL,
        estado CHAR(2) NOT NULL,
        pais VARCHAR(50) NOT NULL CONSTRAINT DF_DIM_CLIENTE_pais DEFAULT 'Brasil',
        cep VARCHAR(10) NULL,

        data_primeiro_cadastro DATE NOT NULL,
        data_ultima_compra DATE NULL,
        data_ultima_atualizacao DATETIME NOT NULL CONSTRAINT DF_DIM_CLIENTE_data_ultima_atualizacao DEFAULT GETDATE(),

        total_compras_historico INT NOT NULL CONSTRAINT DF_DIM_CLIENTE_total_compras_historico DEFAULT 0,
        valor_total_gasto_historico DECIMAL(12,2) NOT NULL CONSTRAINT DF_DIM_CLIENTE_valor_total_gasto_historico DEFAULT 0,
        ticket_medio_historico DECIMAL(10,2) NULL,

        eh_ativo BIT NOT NULL CONSTRAINT DF_DIM_CLIENTE_eh_ativo DEFAULT 1,
        aceita_email_marketing BIT NOT NULL CONSTRAINT DF_DIM_CLIENTE_aceita_email_marketing DEFAULT 0,
        eh_cliente_vip BIT NOT NULL CONSTRAINT DF_DIM_CLIENTE_eh_cliente_vip DEFAULT 0,

        CONSTRAINT PK_DIM_CLIENTE PRIMARY KEY CLUSTERED (cliente_id),
        CONSTRAINT UK_DIM_CLIENTE_original_id UNIQUE (cliente_original_id),
        CONSTRAINT CK_DIM_CLIENTE_tipo CHECK (tipo_cliente IN ('Novo', 'Recorrente', 'VIP', 'Inativo')),
        CONSTRAINT CK_DIM_CLIENTE_segmento CHECK (segmento IN ('Pessoa Fisica', 'Pessoa Juridica', 'Pessoa Física', 'Pessoa Jurídica')),
        CONSTRAINT CK_DIM_CLIENTE_genero CHECK (genero IN ('M', 'F', 'O') OR genero IS NULL),
        CONSTRAINT CK_DIM_CLIENTE_estado CHECK (LEN(estado) = 2)
    );

    PRINT 'Tabela dim.DIM_CLIENTE criada.';
END
ELSE
BEGIN
    PRINT 'Tabela dim.DIM_CLIENTE ja existe. Mantendo dados persistidos.';
END;
GO

DECLARE @missing_columns TABLE (column_name SYSNAME NOT NULL);

INSERT INTO @missing_columns (column_name)
SELECT v.column_name
FROM (
    VALUES
        ('cliente_original_id'),
        ('nome_cliente'),
        ('email'),
        ('telefone'),
        ('cpf_cnpj'),
        ('data_nascimento'),
        ('genero'),
        ('tipo_cliente'),
        ('segmento'),
        ('score_credito'),
        ('categoria_valor'),
        ('endereco_completo'),
        ('bairro'),
        ('cidade'),
        ('estado'),
        ('pais'),
        ('cep'),
        ('data_primeiro_cadastro'),
        ('data_ultima_compra'),
        ('data_ultima_atualizacao'),
        ('eh_ativo'),
        ('aceita_email_marketing'),
        ('eh_cliente_vip')
) AS v(column_name)
WHERE COL_LENGTH('dim.DIM_CLIENTE', v.column_name) IS NULL;

IF EXISTS (SELECT 1 FROM @missing_columns)
BEGIN
    DECLARE @missing_list NVARCHAR(MAX);
    SELECT @missing_list = STRING_AGG(column_name, ', ') FROM @missing_columns;
    RAISERROR('dim.DIM_CLIENTE sem colunas obrigatorias: %s', 16, 1, @missing_list);
    RETURN;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'IX_DIM_CLIENTE_original_id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_original_id
        ON dim.DIM_CLIENTE(cliente_original_id)
        INCLUDE (cliente_id, nome_cliente);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'IX_DIM_CLIENTE_localizacao'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_localizacao
        ON dim.DIM_CLIENTE(estado, cidade)
        INCLUDE (cliente_id, nome_cliente, tipo_cliente);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'IX_DIM_CLIENTE_tipo_segmento'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_tipo_segmento
        ON dim.DIM_CLIENTE(tipo_cliente, segmento)
        INCLUDE (cliente_id);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'IX_DIM_CLIENTE_nome'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_nome
        ON dim.DIM_CLIENTE(nome_cliente);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_CLIENTE')
      AND name = 'IX_DIM_CLIENTE_ativo'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_ativo
        ON dim.DIM_CLIENTE(eh_ativo)
        INCLUDE (cliente_id, tipo_cliente);
END;
GO

CREATE OR ALTER VIEW dim.VW_CLIENTES_ATIVOS
AS
SELECT
    cliente_id,
    cliente_original_id,
    nome_cliente,
    email,
    telefone,
    tipo_cliente,
    segmento,
    cidade,
    estado,
    pais,
    data_primeiro_cadastro,
    data_ultima_compra,
    total_compras_historico,
    valor_total_gasto_historico,
    ticket_medio_historico,
    eh_cliente_vip,
    aceita_email_marketing,
    CASE
        WHEN data_ultima_compra IS NULL THEN NULL
        ELSE DATEDIFF(DAY, data_ultima_compra, GETDATE())
    END AS dias_desde_ultima_compra
FROM dim.DIM_CLIENTE
WHERE eh_ativo = 1;
GO

PRINT 'dim.DIM_CLIENTE validada com sucesso (modo idempotente).';
GO
