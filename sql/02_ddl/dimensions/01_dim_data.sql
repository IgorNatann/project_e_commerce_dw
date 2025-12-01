-- ========================================
-- SCRIPT: 01_dim_data.sql
-- DESCRIÇÃO: Criação e população da DIM_DATA
-- AUTOR: Seu Nome
-- DATA: 2024-12-01
-- PRÉ-REQUISITO: Scripts em 01_setup executados
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_DATA';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_DATA', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_DATA;
    PRINT '⚠️  Tabela dim.DIM_DATA existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_DATA
-- ========================================

PRINT 'Criando tabela dim.DIM_DATA...';

CREATE TABLE dim.DIM_DATA
(
    -- ============ CHAVE PRIMÁRIA ============
    data_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============ DATA COMPLETA (Natural Key) ============
    data_completa DATE NOT NULL,
    
    -- ============ HIERARQUIA TEMPORAL ============
    ano INT NOT NULL,
    trimestre INT NOT NULL,          -- 1, 2, 3, 4
    mes INT NOT NULL,                -- 1-12
    dia INT NOT NULL,                -- 1-31
    
    -- ============ SEMANA ============
    semana_do_ano INT NOT NULL,      -- 1-53
    dia_da_semana INT NOT NULL,      -- 1=Domingo, 2=Segunda, ..., 7=Sábado
    
    -- ============ ATRIBUTOS DESCRITIVOS ============
    nome_mes VARCHAR(20) NOT NULL,           -- 'Janeiro', 'Fevereiro', ...
    nome_mes_abrev VARCHAR(3) NOT NULL,      -- 'Jan', 'Fev', ...
    nome_dia_semana VARCHAR(20) NOT NULL,    -- 'Domingo', 'Segunda-feira', ...
    nome_dia_semana_abrev VARCHAR(3) NOT NULL, -- 'Dom', 'Seg', ...
    
    -- ============ FLAGS ============
    eh_fim_de_semana BIT NOT NULL,   -- 0=Não, 1=Sim (Sábado/Domingo)
    eh_feriado BIT NOT NULL,         -- 0=Não, 1=Sim
    nome_feriado VARCHAR(50) NULL,   -- 'Natal', 'Ano Novo', NULL
    
    -- ============ OUTROS ATRIBUTOS ============
    dia_do_ano INT NOT NULL,         -- 1-366
    eh_ano_bissexto BIT NOT NULL,    -- 0=Não, 1=Sim
    
    -- ============ PERÍODOS FORMATADOS ============
    periodo_mes VARCHAR(7) NOT NULL,        -- '2024-01'
    periodo_trimestre VARCHAR(7) NOT NULL,  -- '2024-Q1'
    
    -- ============ CONSTRAINTS ============
    CONSTRAINT PK_DIM_DATA PRIMARY KEY CLUSTERED (data_id),
    CONSTRAINT UK_DIM_DATA_data_completa UNIQUE (data_completa),
    CONSTRAINT CK_DIM_DATA_trimestre CHECK (trimestre BETWEEN 1 AND 4),
    CONSTRAINT CK_DIM_DATA_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT CK_DIM_DATA_dia CHECK (dia BETWEEN 1 AND 31)
);
GO

PRINT '✅ Tabela dim.DIM_DATA criada!';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices...';

-- Índice na data completa (natural key) para joins
CREATE NONCLUSTERED INDEX IX_DIM_DATA_data_completa 
    ON dim.DIM_DATA(data_completa)
    INCLUDE (ano, mes, trimestre);
PRINT '  ✅ IX_DIM_DATA_data_completa';

-- Índice composto para queries por ano/mês
CREATE NONCLUSTERED INDEX IX_DIM_DATA_ano_mes 
    ON dim.DIM_DATA(ano, mes)
    INCLUDE (data_completa);
PRINT '  ✅ IX_DIM_DATA_ano_mes';

-- Índice para filtros por trimestre
CREATE NONCLUSTERED INDEX IX_DIM_DATA_ano_trimestre 
    ON dim.DIM_DATA(ano, trimestre);
PRINT '  ✅ IX_DIM_DATA_ano_trimestre';

PRINT '';

-- ========================================
-- 4. POPULAR DIM_DATA (2020-2025)
-- ========================================

PRINT 'Populando DIM_DATA com datas de 2020 a 2025...';
PRINT '';

-- Variáveis de controle
DECLARE @data_inicio DATE = '2020-01-01';
DECLARE @data_fim DATE = '2025-12-31';
DECLARE @data_atual DATE = @data_inicio;
DECLARE @contador INT = 0;

-- Tabela temporária de feriados nacionais (Brasil)
DECLARE @feriados TABLE (data DATE, nome VARCHAR(50));

INSERT INTO @feriados (data, nome) VALUES
    -- 2020
    ('2020-01-01', 'Ano Novo'), ('2020-04-21', 'Tiradentes'), ('2020-05-01', 'Dia do Trabalho'),
    ('2020-09-07', 'Independência'), ('2020-10-12', 'N. Sra. Aparecida'), ('2020-11-02', 'Finados'),
    ('2020-11-15', 'Proclamação República'), ('2020-12-25', 'Natal'),
    -- 2021
    ('2021-01-01', 'Ano Novo'), ('2021-04-21', 'Tiradentes'), ('2021-05-01', 'Dia do Trabalho'),
    ('2021-09-07', 'Independência'), ('2021-10-12', 'N. Sra. Aparecida'), ('2021-11-02', 'Finados'),
    ('2021-11-15', 'Proclamação República'), ('2021-12-25', 'Natal'),
    -- 2022
    ('2022-01-01', 'Ano Novo'), ('2022-04-21', 'Tiradentes'), ('2022-05-01', 'Dia do Trabalho'),
    ('2022-09-07', 'Independência'), ('2022-10-12', 'N. Sra. Aparecida'), ('2022-11-02', 'Finados'),
    ('2022-11-15', 'Proclamação República'), ('2022-12-25', 'Natal'),
    -- 2023
    ('2023-01-01', 'Ano Novo'), ('2023-04-21', 'Tiradentes'), ('2023-05-01', 'Dia do Trabalho'),
    ('2023-09-07', 'Independência'), ('2023-10-12', 'N. Sra. Aparecida'), ('2023-11-02', 'Finados'),
    ('2023-11-15', 'Proclamação República'), ('2023-12-25', 'Natal'),
    -- 2024
    ('2024-01-01', 'Ano Novo'), ('2024-04-21', 'Tiradentes'), ('2024-05-01', 'Dia do Trabalho'),
    ('2024-09-07', 'Independência'), ('2024-10-12', 'N. Sra. Aparecida'), ('2024-11-02', 'Finados'),
    ('2024-11-15', 'Proclamação República'), ('2024-12-25', 'Natal'),
    -- 2025
    ('2025-01-01', 'Ano Novo'), ('2025-04-21', 'Tiradentes'), ('2025-05-01', 'Dia do Trabalho'),
    ('2025-09-07', 'Independência'), ('2025-10-12', 'N. Sra. Aparecida'), ('2025-11-02', 'Finados'),
    ('2025-11-15', 'Proclamação República'), ('2025-12-25', 'Natal');

-- Loop para inserir todas as datas
WHILE @data_atual <= @data_fim
BEGIN
    -- Variáveis auxiliares
    DECLARE @ano INT = YEAR(@data_atual);
    DECLARE @mes INT = MONTH(@data_atual);
    DECLARE @dia INT = DAY(@data_atual);
    DECLARE @dia_semana INT = DATEPART(WEEKDAY, @data_atual);
    DECLARE @eh_feriado BIT = 0;
    DECLARE @nome_feriado VARCHAR(50) = NULL;
    
    -- Verificar se é feriado
    SELECT 
        @eh_feriado = 1, 
        @nome_feriado = nome 
    FROM @feriados 
    WHERE data = @data_atual;
    
    -- Inserir registro
    INSERT INTO dim.DIM_DATA (
        data_completa, ano, trimestre, mes, dia,
        semana_do_ano, dia_da_semana,
        nome_mes, nome_mes_abrev,
        nome_dia_semana, nome_dia_semana_abrev,
        eh_fim_de_semana, eh_feriado, nome_feriado,
        dia_do_ano, eh_ano_bissexto,
        periodo_mes, periodo_trimestre
    )
    VALUES (
        @data_atual,
        @ano,
        DATEPART(QUARTER, @data_atual),
        @mes,
        @dia,
        DATEPART(WEEK, @data_atual),
        @dia_semana,
        -- Nome do mês
        CASE @mes
            WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
            WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Setembro'
            WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
        END,
        -- Nome do mês abreviado
        CASE @mes
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
            WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
        END,
        -- Nome do dia da semana
        CASE @dia_semana
            WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Segunda-feira' WHEN 3 THEN 'Terça-feira'
            WHEN 4 THEN 'Quarta-feira' WHEN 5 THEN 'Quinta-feira' WHEN 6 THEN 'Sexta-feira'
            WHEN 7 THEN 'Sábado'
        END,
        -- Nome do dia da semana abreviado
        CASE @dia_semana
            WHEN 1 THEN 'Dom' WHEN 2 THEN 'Seg' WHEN 3 THEN 'Ter'
            WHEN 4 THEN 'Qua' WHEN 5 THEN 'Qui' WHEN 6 THEN 'Sex'
            WHEN 7 THEN 'Sáb'
        END,
        -- Flags
        CASE WHEN @dia_semana IN (1, 7) THEN 1 ELSE 0 END,  -- Fim de semana
        ISNULL(@eh_feriado, 0),
        @nome_feriado,
        DATEPART(DAYOFYEAR, @data_atual),
        CASE WHEN (@ano % 4 = 0 AND @ano % 100 != 0) OR (@ano % 400 = 0) THEN 1 ELSE 0 END,
        -- Períodos formatados
        FORMAT(@data_atual, 'yyyy-MM'),
        CONCAT(@ano, '-Q', DATEPART(QUARTER, @data_atual))
    );
    
    -- Contador de progresso
    SET @contador = @contador + 1;
    IF @contador % 365 = 0
        PRINT '  ✅ ' + CAST(@contador AS VARCHAR) + ' registros inseridos...';
    
    -- Próximo dia
    SET @data_atual = DATEADD(DAY, 1, @data_atual);
END;

PRINT '';
PRINT '✅ DIM_DATA populada com ' + CAST(@@ROWCOUNT AS VARCHAR) + ' registros!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO (Extended Properties)
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão Temporal - Hierarquia de datas de 2020 a 2025 com feriados nacionais do Brasil.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_DATA';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Chave primária surrogate (auto-incremento)',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_DATA',
    @level2type = N'COLUMN', @level2name = 'data_id';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Data completa (Natural Key) no formato DATE',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_DATA',
    @level2type = N'COLUMN', @level2name = 'data_completa';

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
PRINT '1. Total de Registros:';
SELECT COUNT(*) AS total_registros FROM dim.DIM_DATA;
PRINT '';

-- Registros por ano
PRINT '2. Distribuição por Ano:';
SELECT 
    ano,
    COUNT(*) as total_dias,
    SUM(CASE WHEN eh_feriado = 1 THEN 1 ELSE 0 END) as feriados,
    SUM(CASE WHEN eh_fim_de_semana = 1 THEN 1 ELSE 0 END) as fins_semana
FROM dim.DIM_DATA
GROUP BY ano
ORDER BY ano;
PRINT '';

-- Primeiros registros
PRINT '3. Primeiros 5 Registros:';
SELECT TOP 5 
    data_id,
    data_completa,
    nome_dia_semana,
    nome_mes,
    periodo_trimestre,
    eh_feriado
FROM dim.DIM_DATA
ORDER BY data_completa;
PRINT '';

PRINT '✅ DIM_DATA criada e validada com sucesso!';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO: Execute 02_dim_cliente.sql';
PRINT '========================================';
GO