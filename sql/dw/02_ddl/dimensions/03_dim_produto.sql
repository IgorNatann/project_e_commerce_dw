-- ========================================
-- SCRIPT: 03_dim_produto.sql
-- OBJETIVO: criar/garantir estrutura da dim.DIM_PRODUTO (idempotente)
-- NOTA: nao remove dados existentes
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'DIM_PRODUTO - CREATE/ENSURE (IDEMPOTENTE)';
PRINT '========================================';
PRINT '';
GO

IF SCHEMA_ID('dim') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA dim');
END;
GO

IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NULL
BEGIN
    PRINT 'Criando tabela dim.DIM_PRODUTO...';

    CREATE TABLE dim.DIM_PRODUTO
    (
        produto_id INT IDENTITY(1,1) NOT NULL,
        produto_original_id INT NOT NULL,

        codigo_sku VARCHAR(50) NOT NULL,
        codigo_barras VARCHAR(20) NULL,
        nome_produto VARCHAR(150) NOT NULL,
        descricao_curta VARCHAR(255) NULL,
        descricao_completa VARCHAR(MAX) NULL,

        categoria VARCHAR(50) NOT NULL,
        subcategoria VARCHAR(50) NOT NULL,
        linha_produto VARCHAR(50) NULL,

        marca VARCHAR(50) NOT NULL,
        fabricante VARCHAR(100) NULL,

        fornecedor_id INT NOT NULL,
        nome_fornecedor VARCHAR(100) NOT NULL,
        pais_origem VARCHAR(50) NULL,

        peso_kg DECIMAL(8,3) NULL,
        altura_cm DECIMAL(6,2) NULL,
        largura_cm DECIMAL(6,2) NULL,
        profundidade_cm DECIMAL(6,2) NULL,
        cor_principal VARCHAR(30) NULL,
        material VARCHAR(50) NULL,

        preco_custo DECIMAL(10,2) NOT NULL,
        preco_sugerido DECIMAL(10,2) NOT NULL,
        margem_sugerida_percent DECIMAL(5,2) NULL,

        eh_perecivel BIT NOT NULL CONSTRAINT DF_DIM_PRODUTO_eh_perecivel DEFAULT 0,
        eh_fragil BIT NOT NULL CONSTRAINT DF_DIM_PRODUTO_eh_fragil DEFAULT 0,
        requer_refrigeracao BIT NOT NULL CONSTRAINT DF_DIM_PRODUTO_requer_refrigeracao DEFAULT 0,
        idade_minima_venda INT NULL,

        estoque_minimo INT NOT NULL CONSTRAINT DF_DIM_PRODUTO_estoque_minimo DEFAULT 0,
        estoque_maximo INT NOT NULL CONSTRAINT DF_DIM_PRODUTO_estoque_maximo DEFAULT 1000,
        prazo_reposicao_dias INT NULL,

        situacao VARCHAR(20) NOT NULL CONSTRAINT DF_DIM_PRODUTO_situacao DEFAULT 'Ativo',
        data_lancamento DATE NULL,
        data_descontinuacao DATE NULL,

        data_cadastro DATETIME NOT NULL CONSTRAINT DF_DIM_PRODUTO_data_cadastro DEFAULT GETDATE(),
        data_ultima_atualizacao DATETIME NOT NULL CONSTRAINT DF_DIM_PRODUTO_data_ultima_atualizacao DEFAULT GETDATE(),

        palavras_chave VARCHAR(200) NULL,
        avaliacao_media DECIMAL(2,1) NULL,
        total_avaliacoes INT NOT NULL CONSTRAINT DF_DIM_PRODUTO_total_avaliacoes DEFAULT 0,

        CONSTRAINT PK_DIM_PRODUTO PRIMARY KEY CLUSTERED (produto_id),
        CONSTRAINT UK_DIM_PRODUTO_original_id UNIQUE (produto_original_id),
        CONSTRAINT UK_DIM_PRODUTO_sku UNIQUE (codigo_sku),
        CONSTRAINT CK_DIM_PRODUTO_situacao CHECK (situacao IN ('Ativo', 'Inativo', 'Descontinuado')),
        CONSTRAINT CK_DIM_PRODUTO_preco_custo CHECK (preco_custo >= 0),
        CONSTRAINT CK_DIM_PRODUTO_preco_sugerido CHECK (preco_sugerido >= 0),
        CONSTRAINT CK_DIM_PRODUTO_avaliacao CHECK (avaliacao_media BETWEEN 0 AND 5 OR avaliacao_media IS NULL),
        CONSTRAINT CK_DIM_PRODUTO_estoque CHECK (estoque_maximo >= estoque_minimo)
    );

    PRINT 'Tabela dim.DIM_PRODUTO criada.';
END
ELSE
BEGIN
    PRINT 'Tabela dim.DIM_PRODUTO ja existe. Mantendo dados persistidos.';
END;
GO

DECLARE @missing_columns TABLE (column_name SYSNAME NOT NULL);

INSERT INTO @missing_columns (column_name)
SELECT v.column_name
FROM (
    VALUES
        ('produto_original_id'),
        ('codigo_sku'),
        ('codigo_barras'),
        ('nome_produto'),
        ('descricao_curta'),
        ('descricao_completa'),
        ('categoria'),
        ('subcategoria'),
        ('linha_produto'),
        ('marca'),
        ('fabricante'),
        ('fornecedor_id'),
        ('nome_fornecedor'),
        ('pais_origem'),
        ('peso_kg'),
        ('altura_cm'),
        ('largura_cm'),
        ('profundidade_cm'),
        ('cor_principal'),
        ('material'),
        ('preco_custo'),
        ('preco_sugerido'),
        ('margem_sugerida_percent'),
        ('eh_perecivel'),
        ('eh_fragil'),
        ('requer_refrigeracao'),
        ('idade_minima_venda'),
        ('estoque_minimo'),
        ('estoque_maximo'),
        ('prazo_reposicao_dias'),
        ('situacao'),
        ('data_lancamento'),
        ('data_descontinuacao'),
        ('data_cadastro'),
        ('data_ultima_atualizacao'),
        ('palavras_chave'),
        ('avaliacao_media'),
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

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_original_id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_original_id
        ON dim.DIM_PRODUTO(produto_original_id)
        INCLUDE (produto_id, nome_produto, preco_sugerido);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_sku'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_sku
        ON dim.DIM_PRODUTO(codigo_sku)
        INCLUDE (produto_id, nome_produto);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_hierarquia'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_hierarquia
        ON dim.DIM_PRODUTO(categoria, subcategoria, marca)
        INCLUDE (produto_id, nome_produto, preco_sugerido);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_fornecedor'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_fornecedor
        ON dim.DIM_PRODUTO(fornecedor_id, nome_fornecedor)
        INCLUDE (produto_id, categoria);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_situacao'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_situacao
        ON dim.DIM_PRODUTO(situacao)
        INCLUDE (produto_id, categoria, marca);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_PRODUTO')
      AND name = 'IX_DIM_PRODUTO_nome'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_nome
        ON dim.DIM_PRODUTO(nome_produto);
END;
GO

CREATE OR ALTER VIEW dim.VW_CATALOGO_PRODUTOS
AS
SELECT
    p.produto_id,
    p.codigo_sku,
    p.nome_produto,
    p.categoria,
    p.subcategoria,
    p.marca,
    p.nome_fornecedor,
    p.preco_sugerido,
    p.avaliacao_media,
    p.total_avaliacoes,
    CASE
        WHEN p.estoque_minimo > 0 THEN 'Disponivel'
        ELSE 'Sob Encomenda'
    END AS disponibilidade,
    CASE
        WHEN p.preco_sugerido < 100 THEN 'Ate R$ 100'
        WHEN p.preco_sugerido < 500 THEN 'R$ 100 a R$ 500'
        WHEN p.preco_sugerido < 1000 THEN 'R$ 500 a R$ 1.000'
        WHEN p.preco_sugerido < 3000 THEN 'R$ 1.000 a R$ 3.000'
        ELSE 'Acima de R$ 3.000'
    END AS faixa_preco,
    CASE
        WHEN p.avaliacao_media >= 4.5 AND p.total_avaliacoes >= 100 THEN 'Premium'
        WHEN p.avaliacao_media >= 4.0 AND p.total_avaliacoes >= 50 THEN 'Recomendado'
        ELSE 'Padrao'
    END AS selo_qualidade
FROM dim.DIM_PRODUTO AS p
WHERE p.situacao = 'Ativo';
GO

PRINT 'dim.DIM_PRODUTO validada com sucesso (modo idempotente).';
GO
