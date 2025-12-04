-- ========================================
-- SCRIPT: 03_dim_produto.sql
-- DESCRIÇÃO: Criação da DIM_PRODUTO
-- AUTOR: Seu Nome
-- DATA: 2024-12-01
-- PRÉ-REQUISITO: 02_dim_cliente.sql executado
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_PRODUTO';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_PRODUTO;
    PRINT '⚠️  Tabela dim.DIM_PRODUTO existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_PRODUTO
-- ========================================

PRINT 'Criando tabela dim.DIM_PRODUTO...';

CREATE TABLE dim.DIM_PRODUTO
(
    -- ============ CHAVE PRIMÁRIA ============
    produto_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============ NATURAL KEY ============
    produto_original_id INT NOT NULL,       -- ID do sistema transacional
    
    -- ============ IDENTIFICAÇÃO ============
    codigo_sku VARCHAR(50) NOT NULL,        -- Stock Keeping Unit
    codigo_barras VARCHAR(20) NULL,         -- EAN-13 ou similar
    nome_produto VARCHAR(150) NOT NULL,
    descricao_curta VARCHAR(255) NULL,
    descricao_completa VARCHAR(MAX) NULL,
    
    -- ============ HIERARQUIA DE CATEGORIA ============
    -- Para drill-down/roll-up: Categoria → Subcategoria → Produto
    categoria VARCHAR(50) NOT NULL,         -- Ex: 'Eletrônicos', 'Moda', 'Casa'
    subcategoria VARCHAR(50) NOT NULL,      -- Ex: 'Notebooks', 'Smartphones'
    linha_produto VARCHAR(50) NULL,         -- Ex: 'Linha Gamer', 'Linha Profissional'
    
    -- ============ MARCA ============
    marca VARCHAR(50) NOT NULL,             -- Ex: 'Dell', 'Samsung', 'Nike'
    fabricante VARCHAR(100) NULL,           -- Pode ser diferente da marca
    
    -- ============ FORNECEDOR ============
    fornecedor_id INT NOT NULL,             -- ID do fornecedor principal
    nome_fornecedor VARCHAR(100) NOT NULL,
    pais_origem VARCHAR(50) NULL,           -- País de origem do produto
    
    -- ============ ATRIBUTOS FÍSICOS ============
    peso_kg DECIMAL(8,3) NULL,              -- Peso em quilogramas
    altura_cm DECIMAL(6,2) NULL,            -- Altura em centímetros
    largura_cm DECIMAL(6,2) NULL,           -- Largura em centímetros
    profundidade_cm DECIMAL(6,2) NULL,      -- Profundidade em centímetros
    cor_principal VARCHAR(30) NULL,
    material VARCHAR(50) NULL,
    
    -- ============ PRECIFICAÇÃO ============
    preco_custo DECIMAL(10,2) NOT NULL,     -- Custo de aquisição
    preco_sugerido DECIMAL(10,2) NOT NULL,  -- Preço de tabela (sem desconto)
    margem_sugerida_percent DECIMAL(5,2) NULL, -- Margem em %
    
    -- ============ CARACTERÍSTICAS ============
    eh_perecivel BIT NOT NULL DEFAULT 0,
    eh_fragil BIT NOT NULL DEFAULT 0,
    requer_refrigeracao BIT NOT NULL DEFAULT 0,
    idade_minima_venda INT NULL,            -- NULL se não tem restrição
    
    -- ============ ESTOQUE E DISPONIBILIDADE ============
    estoque_minimo INT NOT NULL DEFAULT 0,
    estoque_maximo INT NOT NULL DEFAULT 1000,
    prazo_reposicao_dias INT NULL,          -- Dias para reposição
    
    -- ============ STATUS ============
    situacao VARCHAR(20) NOT NULL DEFAULT 'Ativo', -- 'Ativo', 'Inativo', 'Descontinuado'
    data_lancamento DATE NULL,
    data_descontinuacao DATE NULL,
    
    -- ============ ATRIBUTOS TEMPORAIS ============
    data_cadastro DATETIME NOT NULL DEFAULT GETDATE(),
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- ============ SEO / E-COMMERCE ============
    palavras_chave VARCHAR(200) NULL,       -- Para busca
    avaliacao_media DECIMAL(2,1) NULL,      -- 0.0 a 5.0
    total_avaliacoes INT NOT NULL DEFAULT 0,
    
    -- ============ CONSTRAINTS ============
    CONSTRAINT PK_DIM_PRODUTO PRIMARY KEY CLUSTERED (produto_id),
    CONSTRAINT UK_DIM_PRODUTO_original_id UNIQUE (produto_original_id),
    CONSTRAINT UK_DIM_PRODUTO_sku UNIQUE (codigo_sku),
    CONSTRAINT CK_DIM_PRODUTO_situacao CHECK (situacao IN ('Ativo', 'Inativo', 'Descontinuado')),
    CONSTRAINT CK_DIM_PRODUTO_preco_custo CHECK (preco_custo >= 0),
    CONSTRAINT CK_DIM_PRODUTO_preco_sugerido CHECK (preco_sugerido >= 0),
    CONSTRAINT CK_DIM_PRODUTO_avaliacao CHECK (avaliacao_media BETWEEN 0 AND 5 OR avaliacao_media IS NULL),
    CONSTRAINT CK_DIM_PRODUTO_estoque CHECK (estoque_maximo >= estoque_minimo)
);
GO

PRINT '✅ Tabela dim.DIM_PRODUTO criada!';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices...';

-- Índice no original_id (natural key)
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_original_id 
    ON dim.DIM_PRODUTO(produto_original_id)
    INCLUDE (produto_id, nome_produto, preco_sugerido);
PRINT '  ✅ IX_DIM_PRODUTO_original_id';

-- Índice no SKU (busca frequente)
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_sku 
    ON dim.DIM_PRODUTO(codigo_sku)
    INCLUDE (produto_id, nome_produto);
PRINT '  ✅ IX_DIM_PRODUTO_sku';

-- Índice para hierarquia de categoria (drill-down)
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_hierarquia 
    ON dim.DIM_PRODUTO(categoria, subcategoria, marca)
    INCLUDE (produto_id, nome_produto, preco_sugerido);
PRINT '  ✅ IX_DIM_PRODUTO_hierarquia';

-- Índice para análises por fornecedor
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_fornecedor 
    ON dim.DIM_PRODUTO(fornecedor_id, nome_fornecedor)
    INCLUDE (produto_id, categoria);
PRINT '  ✅ IX_DIM_PRODUTO_fornecedor';

-- Índice para filtros de produtos ativos
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_situacao 
    ON dim.DIM_PRODUTO(situacao)
    INCLUDE (produto_id, categoria, marca);
PRINT '  ✅ IX_DIM_PRODUTO_situacao';

-- Índice para busca por nome
CREATE NONCLUSTERED INDEX IX_DIM_PRODUTO_nome 
    ON dim.DIM_PRODUTO(nome_produto);
PRINT '  ✅ IX_DIM_PRODUTO_nome';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT 'Inserindo produtos de exemplo...';
PRINT '';

-- Produto 1: Notebook Dell
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg, altura_cm, largura_cm, profundidade_cm,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, avaliacao_media, total_avaliacoes
)
VALUES (
    1, 'DELL-NB-INS15-001', '7891234567890', 'Notebook Dell Inspiron 15 i5 8GB 256GB SSD',
    'Notebook Dell Inspiron 15 com processador Intel Core i5, 8GB RAM, 256GB SSD',
    'Eletrônicos', 'Notebooks', 'Linha Inspiron',
    'Dell', 'Dell Inc.', 101, 'Tech Supply Distribuidor', 'Estados Unidos',
    2.150, 2.5, 35.8, 24.0,
    2400.00, 3499.00, 31.42,
    5, 50, 15,
    'Ativo', '2023-06-15', 4.5, 127
);

-- Produto 2: Smartphone Samsung
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg, altura_cm, largura_cm, profundidade_cm, cor_principal,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, avaliacao_media, total_avaliacoes
)
VALUES (
    2, 'SAMS-SM-A54-128-BK', '7899876543210', 'Smartphone Samsung Galaxy A54 5G 128GB Preto',
    'Samsung Galaxy A54 5G, Tela 6.4", 128GB, Câmera Tripla 50MP',
    'Eletrônicos', 'Smartphones', 'Linha Galaxy A',
    'Samsung', 'Samsung Electronics', 102, 'Mobile Parts Ltda', 'Coreia do Sul',
    0.202, 15.9, 7.7, 0.82, 'Preto',
    1350.00, 1999.00, 32.47,
    10, 100, 10,
    'Ativo', '2023-03-20', 4.7, 342
);

-- Produto 3: Tênis Nike
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg, cor_principal, material,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, avaliacao_media, total_avaliacoes
)
VALUES (
    3, 'NIKE-TNS-REV-42-BK', '7891122334455', 'Tênis Nike Revolution 6 Masculino Preto Tam 42',
    'Tênis Nike Revolution 6 para corrida, Tam 42, Preto/Branco',
    'Moda', 'Calçados Esportivos', 'Linha Revolution',
    'Nike', 'Nike Inc.', 103, 'Sport Fashion Atacado', 'Vietnã',
    0.450, 'Preto', 'Mesh/Borracha',
    180.00, 349.90, 48.56,
    20, 200, 20,
    'Ativo', '2023-01-10', 4.3, 89
);

-- Produto 4: Cafeteira Nespresso
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg, altura_cm, largura_cm, profundidade_cm, cor_principal,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    eh_fragil, estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, avaliacao_media, total_avaliacoes
)
VALUES (
    4, 'NESP-CF-ESS-MINI-RD', '7895544332211', 'Cafeteira Nespresso Essenza Mini Vermelha',
    'Cafeteira Nespresso Essenza Mini, Sistema de Cápsulas, 19 bar',
    'Casa e Cozinha', 'Cafeteiras', 'Linha Essenza',
    'Nespresso', 'Nestlé Nespresso', 104, 'Casa & Lar Distribuidor', 'Suíça',
    2.300, 23.2, 11.0, 32.5, 'Vermelho',
    380.00, 599.00, 36.56,
    1, 3, 30, 25,
    'Ativo', '2022-08-05', 4.6, 215
);

-- Produto 5: Livro (Produto Descontinuado)
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, data_descontinuacao, avaliacao_media, total_avaliacoes
)
VALUES (
    5, 'LIV-FIC-DATW-001', '9788535911664', 'Livro - Data Warehouse Toolkit (1ª Edição)',
    'Data Warehouse Toolkit - Ralph Kimball - 1ª Edição em Português',
    'Livros', 'Tecnologia', NULL,
    'Editora Campus', 'Grupo GEN', 105, 'Livraria Central', 'Brasil',
    0.850,
    45.00, 89.90, 49.94,
    0, 10, 30,
    'Descontinuado', '2010-03-15', '2018-12-31', 4.9, 54
);

-- Produto 6: Mouse Logitech
INSERT INTO dim.DIM_PRODUTO (
    produto_original_id, codigo_sku, codigo_barras, nome_produto,
    descricao_curta, categoria, subcategoria, linha_produto,
    marca, fabricante, fornecedor_id, nome_fornecedor, pais_origem,
    peso_kg, altura_cm, largura_cm, profundidade_cm, cor_principal,
    preco_custo, preco_sugerido, margem_sugerida_percent,
    estoque_minimo, estoque_maximo, prazo_reposicao_dias,
    situacao, data_lancamento, avaliacao_media, total_avaliacoes
)
VALUES (
    6, 'LOGI-MS-MX-MAST3-BK', '7896543210987', 'Mouse Logitech MX Master 3 Wireless Preto',
    'Mouse Logitech MX Master 3, Wireless, 7 Botões, 4000 DPI',
    'Eletrônicos', 'Periféricos', 'Linha MX',
    'Logitech', 'Logitech International', 101, 'Tech Supply Distribuidor', 'China',
    0.141, 5.1, 8.4, 12.4, 'Preto',
    280.00, 549.90, 49.07,
    5, 50, 15,
    'Ativo', '2023-07-20', 4.8, 178
);

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' produtos de exemplo inseridos!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão de Produtos - Catálogo completo com hierarquia de categorias, fornecedores e atributos físicos. SCD Type 1.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_PRODUTO';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Hierarquia para drill-down: Categoria → Subcategoria → Linha Produto. Ex: Eletrônicos → Notebooks → Linha Gamer',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_PRODUTO',
    @level2type = N'COLUMN', @level2name = 'categoria';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Stock Keeping Unit - Código único do produto no estoque',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_PRODUTO',
    @level2type = N'COLUMN', @level2name = 'codigo_sku';

PRINT '✅ Documentação adicionada!';
PRINT '';

-- ========================================
-- 6. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- Total de registros
PRINT '1. Total de Produtos:';
SELECT COUNT(*) AS total_produtos FROM dim.DIM_PRODUTO;
PRINT '';

-- Distribuição por categoria
PRINT '2. Distribuição por Categoria:';
SELECT 
    categoria,
    COUNT(*) AS total_produtos,
    AVG(preco_sugerido) AS preco_medio,
    AVG(margem_sugerida_percent) AS margem_media
FROM dim.DIM_PRODUTO
GROUP BY categoria
ORDER BY total_produtos DESC;
PRINT '';

-- Hierarquia de categorias
PRINT '3. Hierarquia Categoria → Subcategoria:';
SELECT 
    categoria,
    subcategoria,
    COUNT(*) AS total_produtos,
    MIN(preco_sugerido) AS preco_minimo,
    MAX(preco_sugerido) AS preco_maximo
FROM dim.DIM_PRODUTO
GROUP BY categoria, subcategoria
ORDER BY categoria, subcategoria;
PRINT '';

-- Produtos por fornecedor
PRINT '4. Produtos por Fornecedor:';
SELECT 
    fornecedor_id,
    nome_fornecedor,
    COUNT(*) AS total_produtos,
    AVG(preco_custo) AS custo_medio
FROM dim.DIM_PRODUTO
GROUP BY fornecedor_id, nome_fornecedor
ORDER BY total_produtos DESC;
PRINT '';

-- Produtos por situação
PRINT '5. Produtos por Situação:';
SELECT 
    situacao,
    COUNT(*) AS total
FROM dim.DIM_PRODUTO
GROUP BY situacao;
PRINT '';

-- Amostra de produtos
PRINT '6. Amostra de Produtos:';
SELECT 
    produto_id,
    codigo_sku,
    nome_produto,
    categoria,
    subcategoria,
    marca,
    CAST(preco_custo AS DECIMAL(8,2)) AS custo,
    CAST(preco_sugerido AS DECIMAL(8,2)) AS preco,
    CAST(margem_sugerida_percent AS DECIMAL(5,2)) AS margem_pct,
    situacao
FROM dim.DIM_PRODUTO
ORDER BY produto_id;
PRINT '';

-- Top produtos por avaliação
PRINT '7. Top 3 Produtos Mais Bem Avaliados:';
SELECT TOP 3
    nome_produto,
    categoria,
    avaliacao_media,
    total_avaliacoes,
    preco_sugerido
FROM dim.DIM_PRODUTO
WHERE total_avaliacoes >= 50  -- Mínimo de avaliações
ORDER BY avaliacao_media DESC, total_avaliacoes DESC;
PRINT '';

-- ========================================
-- 7. VIEW AUXILIAR
-- ========================================

PRINT 'Criando view auxiliar...';

-- View para catálogo de produtos ativos
IF OBJECT_ID('dim.VW_CATALOGO_PRODUTOS', 'V') IS NOT NULL
    DROP VIEW dim.VW_CATALOGO_PRODUTOS;
GO

CREATE VIEW dim.VW_CATALOGO_PRODUTOS
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
    -- Atributos úteis para e-commerce
    CASE 
        WHEN p.estoque_minimo > 0 THEN 'Disponível'
        ELSE 'Sob Encomenda'
    END AS disponibilidade,
    -- Faixa de preço
    CASE 
        WHEN p.preco_sugerido < 100 THEN 'Até R$ 100'
        WHEN p.preco_sugerido < 500 THEN 'R$ 100 a R$ 500'
        WHEN p.preco_sugerido < 1000 THEN 'R$ 500 a R$ 1.000'
        WHEN p.preco_sugerido < 3000 THEN 'R$ 1.000 a R$ 3.000'
        ELSE 'Acima de R$ 3.000'
    END AS faixa_preco,
    -- Selo de qualidade
    CASE 
        WHEN p.avaliacao_media >= 4.5 AND p.total_avaliacoes >= 100 THEN 'Premium'
        WHEN p.avaliacao_media >= 4.0 AND p.total_avaliacoes >= 50 THEN 'Recomendado'
        ELSE 'Padrão'
    END AS selo_qualidade
FROM dim.DIM_PRODUTO p
WHERE p.situacao = 'Ativo';
GO

PRINT '✅ View dim.VW_CATALOGO_PRODUTOS criada!';
PRINT '';

PRINT '✅ DIM_PRODUTO criada e validada com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO: Execute 04_dim_regiao.sql';
PRINT '========================================';
GO
