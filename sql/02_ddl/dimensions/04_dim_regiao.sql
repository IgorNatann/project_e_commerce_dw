-- ========================================
-- SCRIPT: 04_dim_regiao.sql
-- DESCRIÇÃO: Criação da DIM_REGIAO
-- AUTOR: Igor Natan    
-- DATA: 2024-12-04
-- PRÉ-REQUISITO: 03_dim_produto.sql executado
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_REGIAO';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_REGIAO', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_REGIAO;
    PRINT '⚠️  Tabela dim.DIM_REGIAO existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_REGIAO
-- ========================================

PRINT 'Criando tabela dim.DIM_REGIAO...';

CREATE TABLE dim.DIM_REGIAO
(
    -- ============ CHAVE PRIMÁRIA ============
    regiao_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============ NATURAL KEY ============
    regiao_original_id INT NOT NULL,        -- ID do sistema transacional
    
    -- ============ HIERARQUIA GEOGRÁFICA ============
    -- Para drill-down: País → Região → Estado → Cidade
    pais VARCHAR(50) NOT NULL,              -- Brasil, Argentina, etc
    regiao_pais VARCHAR(30) NULL,           -- Sudeste, Nordeste, Sul, Norte, Centro-Oeste
    estado CHAR(2) NOT NULL,                -- SP, RJ, MG, etc
    nome_estado VARCHAR(50) NOT NULL,       -- São Paulo, Rio de Janeiro, etc
    cidade VARCHAR(100) NOT NULL,           -- São Paulo, Campinas, etc
    
    -- ============ CÓDIGOS E IDENTIFICADORES ============
    codigo_ibge VARCHAR(10) NULL,           -- Código IBGE da cidade
    cep_inicial VARCHAR(10) NULL,           -- CEP inicial da região
    cep_final VARCHAR(10) NULL,             -- CEP final da região
    ddd CHAR(2) NULL,                       -- Código DDD
    
    -- ============ ATRIBUTOS DEMOGRÁFICOS ============
    populacao_estimada INT NULL,            -- População da cidade
    area_km2 DECIMAL(10,2) NULL,            -- Área em km²
    densidade_demografica DECIMAL(10,2) NULL, -- Habitantes por km²
    
    -- ============ CLASSIFICAÇÃO ============
    tipo_municipio VARCHAR(30) NULL,        -- Capital, Interior, Região Metropolitana
    porte_municipio VARCHAR(20) NULL,       -- Grande, Médio, Pequeno
    
    -- ============ INFORMAÇÕES ECONÔMICAS ============
    pib_per_capita DECIMAL(10,2) NULL,      -- PIB per capita (estimado)
    idh DECIMAL(4,3) NULL,                  -- Índice de Desenvolvimento Humano (0-1)
    
    -- ============ LOCALIZAÇÃO ============
    latitude DECIMAL(10,7) NULL,            -- Coordenadas geográficas
    longitude DECIMAL(10,7) NULL,
    fuso_horario VARCHAR(50) NULL,          -- America/Sao_Paulo, etc
    
    -- ============ ATRIBUTOS TEMPORAIS ============
    data_cadastro DATETIME NOT NULL DEFAULT GETDATE(),
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- ============ STATUS ============
    eh_ativo BIT NOT NULL DEFAULT 1,        -- 0=Inativo, 1=Ativo
    
    -- ============ CONSTRAINTS ============
    CONSTRAINT PK_DIM_REGIAO PRIMARY KEY CLUSTERED (regiao_id),
    CONSTRAINT UK_DIM_REGIAO_original_id UNIQUE (regiao_original_id),
    CONSTRAINT UK_DIM_REGIAO_localizacao UNIQUE (pais, estado, cidade),
    CONSTRAINT CK_DIM_REGIAO_estado CHECK (LEN(estado) = 2),
    CONSTRAINT CK_DIM_REGIAO_idh CHECK (idh BETWEEN 0 AND 1 OR idh IS NULL),
    CONSTRAINT CK_DIM_REGIAO_populacao CHECK (populacao_estimada > 0 OR populacao_estimada IS NULL)
);
GO

PRINT '✅ Tabela dim.DIM_REGIAO criada!';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices...';

-- Índice no original_id
CREATE NONCLUSTERED INDEX IX_DIM_REGIAO_original_id 
    ON dim.DIM_REGIAO(regiao_original_id)
    INCLUDE (regiao_id, cidade, estado);
PRINT '  ✅ IX_DIM_REGIAO_original_id';

-- Índice para hierarquia geográfica
CREATE NONCLUSTERED INDEX IX_DIM_REGIAO_hierarquia 
    ON dim.DIM_REGIAO(pais, regiao_pais, estado, cidade)
    INCLUDE (regiao_id);
PRINT '  ✅ IX_DIM_REGIAO_hierarquia';

-- Índice para filtros por estado
CREATE NONCLUSTERED INDEX IX_DIM_REGIAO_estado 
    ON dim.DIM_REGIAO(estado)
    INCLUDE (regiao_id, cidade, regiao_pais);
PRINT '  ✅ IX_DIM_REGIAO_estado';

-- Índice para busca por cidade
CREATE NONCLUSTERED INDEX IX_DIM_REGIAO_cidade 
    ON dim.DIM_REGIAO(cidade)
    INCLUDE (estado, regiao_id);
PRINT '  ✅ IX_DIM_REGIAO_cidade';

-- Índice para código IBGE
CREATE NONCLUSTERED INDEX IX_DIM_REGIAO_codigo_ibge 
    ON dim.DIM_REGIAO(codigo_ibge)
    WHERE codigo_ibge IS NOT NULL;
PRINT '  ✅ IX_DIM_REGIAO_codigo_ibge';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT 'Inserindo regiões de exemplo...';
PRINT '';

-- Região 1: São Paulo (Capital)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    1, 'Brasil', 'Sudeste', 'SP', 'São Paulo', 'São Paulo',
    '3550308', '01000-000', '05999-999', '11',
    12325232, 1521.11, 8097.99,
    'Capital', 'Grande', 52796.00, 0.805,
    -23.5505199, -46.6333094, 'America/Sao_Paulo', 1
);

-- Região 2: Rio de Janeiro (Capital)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    2, 'Brasil', 'Sudeste', 'RJ', 'Rio de Janeiro', 'Rio de Janeiro',
    '3304557', '20000-000', '23799-999', '21',
    6747815, 1200.27, 5621.99,
    'Capital', 'Grande', 48142.00, 0.799,
    -22.9068467, -43.1728965, 'America/Sao_Paulo', 1
);

-- Região 3: Belo Horizonte (Capital)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    3, 'Brasil', 'Sudeste', 'MG', 'Minas Gerais', 'Belo Horizonte',
    '3106200', '30000-000', '31999-999', '31',
    2521564, 331.40, 7608.63,
    'Capital', 'Grande', 32629.00, 0.810,
    -19.9166813, -43.9344931, 'America/Sao_Paulo', 1
);

-- Região 4: Porto Alegre (Capital)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    4, 'Brasil', 'Sul', 'RS', 'Rio Grande do Sul', 'Porto Alegre',
    '4314902', '90000-000', '91999-999', '51',
    1492530, 496.68, 3004.37,
    'Capital', 'Grande', 43728.00, 0.805,
    -30.0346471, -51.2176584, 'America/Sao_Paulo', 1
);

-- Região 5: Curitiba (Capital)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    5, 'Brasil', 'Sul', 'PR', 'Paraná', 'Curitiba',
    '4106902', '80000-000', '82999-999', '41',
    1963726, 435.04, 4513.37,
    'Capital', 'Grande', 41122.00, 0.823,
    -25.4284095, -49.2733163, 'America/Sao_Paulo', 1
);

-- Região 6: Campinas (Interior - SP)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    6, 'Brasil', 'Sudeste', 'SP', 'São Paulo', 'Campinas',
    '3509502', '13000-000', '13149-999', '19',
    1213792, 795.70, 1525.64,
    'Região Metropolitana', 'Grande', 47856.00, 0.805,
    -22.9056146, -47.0608329, 'America/Sao_Paulo', 1
);

-- Região 7: Salvador (Capital - Nordeste)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    7, 'Brasil', 'Nordeste', 'BA', 'Bahia', 'Salvador',
    '2927408', '40000-000', '42899-999', '71',
    2886698, 693.45, 4163.28,
    'Capital', 'Grande', 23548.00, 0.759,
    -12.9714, -38.5014, 'America/Sao_Paulo', 1
);

-- Região 8: Brasília (Capital Federal)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    8, 'Brasil', 'Centro-Oeste', 'DF', 'Distrito Federal', 'Brasília',
    '5300108', '70000-000', '73699-999', '61',
    3094325, 5760.78, 537.22,
    'Capital', 'Grande', 79672.00, 0.824,
    -15.8267, -47.9218, 'America/Sao_Paulo', 1
);

-- Região 9: Manaus (Capital - Norte)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    9, 'Brasil', 'Norte', 'AM', 'Amazonas', 'Manaus',
    '1302603', '69000-000', '69099-999', '92',
    2255903, 11401.09, 197.87,
    'Capital', 'Grande', 31062.00, 0.737,
    -3.1190, -60.0217, 'America/Manaus', 1
);

-- Região 10: Goiânia (Capital - Centro-Oeste)
INSERT INTO dim.DIM_REGIAO (
    regiao_original_id, pais, regiao_pais, estado, nome_estado, cidade,
    codigo_ibge, cep_inicial, cep_final, ddd,
    populacao_estimada, area_km2, densidade_demografica,
    tipo_municipio, porte_municipio, pib_per_capita, idh,
    latitude, longitude, fuso_horario, eh_ativo
)
VALUES (
    10, 'Brasil', 'Centro-Oeste', 'GO', 'Goiás', 'Goiânia',
    '5208707', '74000-000', '74899-999', '62',
    1536097, 732.80, 2096.40,
    'Capital', 'Grande', 32911.00, 0.799,
    -16.6869, -49.2648, 'America/Sao_Paulo', 1
);

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' regiões inseridas!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão Geográfica - Hierarquia: País → Região → Estado → Cidade. Usada para análises de localização.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_REGIAO';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Região do país: Norte, Nordeste, Centro-Oeste, Sudeste, Sul',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_REGIAO',
    @level2type = N'COLUMN', @level2name = 'regiao_pais';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Código IBGE da cidade (7 dígitos)',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_REGIAO',
    @level2type = N'COLUMN', @level2name = 'codigo_ibge';

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
PRINT '1. Total de Regiões:';
SELECT COUNT(*) AS total_regioes FROM dim.DIM_REGIAO;
PRINT '';

-- Distribuição por região do país
PRINT '2. Distribuição por Região do País:';
SELECT 
    regiao_pais,
    COUNT(*) AS total_cidades,
    SUM(populacao_estimada) AS populacao_total,
    AVG(pib_per_capita) AS pib_medio
FROM dim.DIM_REGIAO
WHERE regiao_pais IS NOT NULL
GROUP BY regiao_pais
ORDER BY populacao_total DESC;
PRINT '';

-- Distribuição por estado
PRINT '3. Cidades por Estado:';
SELECT 
    estado,
    nome_estado,
    COUNT(*) AS total_cidades,
    SUM(populacao_estimada) AS populacao_total
FROM dim.DIM_REGIAO
GROUP BY estado, nome_estado
ORDER BY populacao_total DESC;
PRINT '';

-- Capitais cadastradas
PRINT '4. Capitais Cadastradas:';
SELECT 
    cidade,
    estado,
    regiao_pais,
    populacao_estimada,
    CAST(pib_per_capita AS DECIMAL(10,2)) AS pib_per_capita,
    CAST(idh AS DECIMAL(4,3)) AS idh
FROM dim.DIM_REGIAO
WHERE tipo_municipio = 'Capital'
ORDER BY populacao_estimada DESC;
PRINT '';

-- Top 5 cidades por população
PRINT '5. Top 5 Cidades por População:';
SELECT TOP 5
    cidade,
    estado,
    populacao_estimada,
    CAST(densidade_demografica AS DECIMAL(10,2)) AS densidade,
    tipo_municipio
FROM dim.DIM_REGIAO
ORDER BY populacao_estimada DESC;
PRINT '';

-- Amostra geral
PRINT '6. Amostra de Regiões:';
SELECT 
    regiao_id,
    cidade,
    estado,
    regiao_pais,
    ddd,
    populacao_estimada,
    tipo_municipio
FROM dim.DIM_REGIAO
ORDER BY regiao_id;
PRINT '';

-- ========================================
-- 7. VIEW AUXILIAR
-- ========================================

PRINT 'View dim.VW_HIERARQUIA_GEOGRAFICA centralizada em sql/04_views/03_vw_hierarquia_geografica.sql';
PRINT 'Definicao removida deste script para evitar duplicidade e drift.';
PRINT '';

PRINT '✅ DIM_REGIAO criada e validada com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO: Execute 05_dim_equipe.sql';
PRINT '========================================';
GO