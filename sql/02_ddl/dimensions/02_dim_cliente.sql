-- ========================================
-- SCRIPT: 02_dim_cliente.sql
-- DESCRIÇÃO: Criação da DIM_CLIENTE
-- AUTOR: Igor Natan
-- DATA: 2025-12-03
-- PRÉ-REQUISITO: 01_dim_data.sql executado
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_CLIENTE';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_CLIENTE;
    PRINT '⚠️  Tabela dim.DIM_CLIENTE existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_CLIENTE
-- ========================================

PRINT 'Criando tabela dim.DIM_CLIENTE...';

CREATE TABLE dim.DIM_CLIENTE
(
    -- ============ CHAVE PRIMÁRIA ============
    cliente_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============ NATURAL KEY ============
    cliente_original_id INT NOT NULL,        -- ID do sistema transacional
    
    -- ============ DADOS PESSOAIS ============
    nome_cliente VARCHAR(100) NOT NULL,
    email VARCHAR(100) NULL,
    telefone VARCHAR(20) NULL,
    cpf_cnpj VARCHAR(18) NULL,              -- Pode ser CPF (11) ou CNPJ (14)
    data_nascimento DATE NULL,
    genero CHAR(1) NULL,                    -- 'M', 'F', 'O', NULL
    
    -- ============ SEGMENTAÇÃO ============
    tipo_cliente VARCHAR(20) NOT NULL,      -- 'Novo', 'Recorrente', 'VIP', 'Inativo'
    segmento VARCHAR(20) NOT NULL,          -- 'Pessoa Física', 'Pessoa Jurídica'
    score_credito INT NULL,                 -- 0-1000 (se aplicável)
    categoria_valor VARCHAR(20) NULL,       -- 'Bronze', 'Prata', 'Ouro', 'Platinum'
    
    -- ============ LOCALIZAÇÃO ============
    endereco_completo VARCHAR(200) NULL,
    numero VARCHAR(10) NULL,
    complemento VARCHAR(50) NULL,
    bairro VARCHAR(50) NULL,
    cidade VARCHAR(100) NOT NULL,
    estado CHAR(2) NOT NULL,                -- 'SP', 'RJ', 'MG', etc
    pais VARCHAR(50) NOT NULL DEFAULT 'Brasil',
    cep VARCHAR(10) NULL,
    
    -- ============ ATRIBUTOS TEMPORAIS ============
    data_primeiro_cadastro DATE NOT NULL,
    data_ultima_compra DATE NULL,           -- NULL se nunca comprou
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- ============ MÉTRICAS DE COMPORTAMENTO ============
    total_compras_historico INT NOT NULL DEFAULT 0,
    valor_total_gasto_historico DECIMAL(12,2) NOT NULL DEFAULT 0,
    ticket_medio_historico DECIMAL(10,2) NULL,
    
    -- ============ FLAGS ============
    eh_ativo BIT NOT NULL DEFAULT 1,        -- 0=Inativo, 1=Ativo
    aceita_email_marketing BIT NOT NULL DEFAULT 0,
    eh_cliente_vip BIT NOT NULL DEFAULT 0,
    
    -- ============ SCD TYPE 1 (Sobrescrever) ============
    -- Campos atualizados: endereço, telefone, email, tipo_cliente
    -- Campos fixos: nome, CPF, data_nascimento, data_primeiro_cadastro
    
    -- ============ CONSTRAINTS ============
    CONSTRAINT PK_DIM_CLIENTE PRIMARY KEY CLUSTERED (cliente_id),
    CONSTRAINT UK_DIM_CLIENTE_original_id UNIQUE (cliente_original_id),
    CONSTRAINT CK_DIM_CLIENTE_tipo CHECK (tipo_cliente IN ('Novo', 'Recorrente', 'VIP', 'Inativo')),
    CONSTRAINT CK_DIM_CLIENTE_segmento CHECK (segmento IN ('Pessoa Física', 'Pessoa Jurídica')),
    CONSTRAINT CK_DIM_CLIENTE_genero CHECK (genero IN ('M', 'F', 'O') OR genero IS NULL),
    CONSTRAINT CK_DIM_CLIENTE_estado CHECK (LEN(estado) = 2)
);
GO

PRINT '✅ Tabela dim.DIM_CLIENTE criada!';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices...';

-- Índice no original_id (natural key) para lookups no ETL
CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_original_id 
    ON dim.DIM_CLIENTE(cliente_original_id)
    INCLUDE (cliente_id, nome_cliente);
PRINT '  ✅ IX_DIM_CLIENTE_original_id';

-- Índice para queries por localização
CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_localizacao 
    ON dim.DIM_CLIENTE(estado, cidade)
    INCLUDE (cliente_id, nome_cliente, tipo_cliente);
PRINT '  ✅ IX_DIM_CLIENTE_localizacao';

-- Índice para queries por tipo/segmento
CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_tipo_segmento 
    ON dim.DIM_CLIENTE(tipo_cliente, segmento)
    INCLUDE (cliente_id);
PRINT '  ✅ IX_DIM_CLIENTE_tipo_segmento';

-- Índice para busca por nome (útil para reports)
CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_nome 
    ON dim.DIM_CLIENTE(nome_cliente);
PRINT '  ✅ IX_DIM_CLIENTE_nome';

-- Índice para filtros de clientes ativos
CREATE NONCLUSTERED INDEX IX_DIM_CLIENTE_ativo 
    ON dim.DIM_CLIENTE(eh_ativo)
    INCLUDE (cliente_id, tipo_cliente);
PRINT '  ✅ IX_DIM_CLIENTE_ativo';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT 'Inserindo dados de exemplo...';
PRINT '(Em produção, isso viria do ETL com dados reais)';
PRINT '';

-- Inserir cliente exemplo 1 - Cliente VIP
INSERT INTO dim.DIM_CLIENTE (
    cliente_original_id, nome_cliente, email, telefone, cpf_cnpj,
    data_nascimento, genero, tipo_cliente, segmento, score_credito,
    categoria_valor, cidade, estado, pais, cep,
    data_primeiro_cadastro, data_ultima_compra,
    total_compras_historico, valor_total_gasto_historico, ticket_medio_historico,
    eh_ativo, aceita_email_marketing, eh_cliente_vip
)
VALUES (
    1, 'João Silva Santos', 'joao.silva@email.com', '(11) 98765-4321', '123.456.789-00',
    '1985-03-15', 'M', 'VIP', 'Pessoa Física', 850,
    'Platinum', 'São Paulo', 'SP', 'Brasil', '01310-100',
    '2020-01-15', '2024-11-28',
    145, 87500.00, 603.45,
    1, 1, 1
);

-- Inserir cliente exemplo 2 - Cliente Recorrente
INSERT INTO dim.DIM_CLIENTE (
    cliente_original_id, nome_cliente, email, telefone, cpf_cnpj,
    data_nascimento, genero, tipo_cliente, segmento, score_credito,
    categoria_valor, cidade, estado, pais, cep,
    data_primeiro_cadastro, data_ultima_compra,
    total_compras_historico, valor_total_gasto_historico, ticket_medio_historico,
    eh_ativo, aceita_email_marketing, eh_cliente_vip
)
VALUES (
    2, 'Maria Oliveira Costa', 'maria.oliveira@email.com', '(21) 99876-5432', '987.654.321-00',
    '1990-07-22', 'F', 'Recorrente', 'Pessoa Física', 720,
    'Ouro', 'Rio de Janeiro', 'RJ', 'Brasil', '22070-900',
    '2021-06-10', '2024-11-15',
    38, 15600.00, 410.53,
    1, 1, 0
);

-- Inserir cliente exemplo 3 - Cliente Novo
INSERT INTO dim.DIM_CLIENTE (
    cliente_original_id, nome_cliente, email, telefone,
    tipo_cliente, segmento, categoria_valor,
    cidade, estado, pais,
    data_primeiro_cadastro,
    total_compras_historico, valor_total_gasto_historico,
    eh_ativo, aceita_email_marketing, eh_cliente_vip
)
VALUES (
    3, 'Carlos Eduardo Mendes', 'carlos.mendes@email.com', '(31) 98888-7777',
    'Novo', 'Pessoa Física', 'Bronze',
    'Belo Horizonte', 'MG', 'Brasil',
    '2024-11-25',
    0, 0.00,
    1, 0, 0
);

-- Inserir cliente exemplo 4 - Pessoa Jurídica
INSERT INTO dim.DIM_CLIENTE (
    cliente_original_id, nome_cliente, email, telefone, cpf_cnpj,
    tipo_cliente, segmento, score_credito, categoria_valor,
    cidade, estado, pais, cep,
    data_primeiro_cadastro, data_ultima_compra,
    total_compras_historico, valor_total_gasto_historico, ticket_medio_historico,
    eh_ativo, aceita_email_marketing, eh_cliente_vip
)
VALUES (
    4, 'Tech Solutions Ltda', 'contato@techsolutions.com.br', '(11) 3456-7890', '12.345.678/0001-90',
    'VIP', 'Pessoa Jurídica', 920,
    'Platinum', 'São Paulo', 'SP', 'Brasil', '04567-000',
    '2019-03-20', '2024-11-20',
    230, 450000.00, 1956.52,
    1, 1, 1
);

-- Inserir cliente exemplo 5 - Cliente Inativo
INSERT INTO dim.DIM_CLIENTE (
    cliente_original_id, nome_cliente, email, cidade, estado, pais,
    tipo_cliente, segmento, categoria_valor,
    data_primeiro_cadastro, data_ultima_compra,
    total_compras_historico, valor_total_gasto_historico, ticket_medio_historico,
    eh_ativo, aceita_email_marketing, eh_cliente_vip
)
VALUES (
    5, 'Ana Paula Ferreira', 'ana.ferreira@email.com',
    'Porto Alegre', 'RS', 'Brasil',
    'Inativo', 'Pessoa Física', 'Prata',
    '2020-05-10', '2022-08-15',
    12, 3200.00, 266.67,
    0, 0, 0
);

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' clientes de exemplo inseridos!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão de Clientes - Contém dados de clientes pessoa física e jurídica. SCD Type 1 (sobrescrever).',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_CLIENTE';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Chave surrogate - auto-incremento',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_CLIENTE',
    @level2type = N'COLUMN', @level2name = 'cliente_id';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Natural key - ID do sistema transacional de origem',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_CLIENTE',
    @level2type = N'COLUMN', @level2name = 'cliente_original_id';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Classificação do cliente: Novo (primeira compra), Recorrente (2+ compras), VIP (alto valor), Inativo (sem compra há 12+ meses)',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_CLIENTE',
    @level2type = N'COLUMN', @level2name = 'tipo_cliente';

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
PRINT '1. Total de Clientes:';
SELECT COUNT(*) AS total_clientes FROM dim.DIM_CLIENTE;
PRINT '';

-- Distribuição por tipo
PRINT '2. Distribuição por Tipo de Cliente:';
SELECT 
    tipo_cliente,
    COUNT(*) AS total,
    SUM(CASE WHEN eh_cliente_vip = 1 THEN 1 ELSE 0 END) AS total_vip
FROM dim.DIM_CLIENTE
GROUP BY tipo_cliente
ORDER BY total DESC;
PRINT '';

-- Distribuição por estado
PRINT '3. Distribuição por Estado:';
SELECT 
    estado,
    COUNT(*) AS total_clientes,
    SUM(valor_total_gasto_historico) AS valor_total_gasto
FROM dim.DIM_CLIENTE
GROUP BY estado
ORDER BY total_clientes DESC;
PRINT '';

-- Clientes por segmento
PRINT '4. Distribuição por Segmento:';
SELECT 
    segmento,
    COUNT(*) AS total,
    AVG(valor_total_gasto_historico) AS ticket_medio,
    SUM(valor_total_gasto_historico) AS valor_total
FROM dim.DIM_CLIENTE
GROUP BY segmento;
PRINT '';

-- Amostra de dados
PRINT '5. Amostra de Clientes:';
SELECT 
    cliente_id,
    nome_cliente,
    tipo_cliente,
    segmento,
    cidade,
    estado,
    total_compras_historico,
    CAST(valor_total_gasto_historico AS DECIMAL(10,2)) AS valor_gasto,
    eh_cliente_vip
FROM dim.DIM_CLIENTE
ORDER BY cliente_id;
PRINT '';

-- ========================================
-- 7. VIEWS AUXILIARES (Opcional)
-- ========================================

PRINT 'Criando view auxiliar...';

-- View para clientes ativos
IF OBJECT_ID('dim.VW_CLIENTES_ATIVOS', 'V') IS NOT NULL
    DROP VIEW dim.VW_CLIENTES_ATIVOS;
GO

CREATE VIEW dim.VW_CLIENTES_ATIVOS
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
    -- Calcular dias desde última compra
    CASE 
        WHEN data_ultima_compra IS NULL THEN NULL
        ELSE DATEDIFF(DAY, data_ultima_compra, GETDATE())
    END AS dias_desde_ultima_compra
FROM dim.DIM_CLIENTE
WHERE eh_ativo = 1;
GO

PRINT '✅ View dim.VW_CLIENTES_ATIVOS criada!';
PRINT '';

PRINT '✅ DIM_CLIENTE criada e validada com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO: Execute 03_dim_produto.sql';
PRINT '========================================';
GO