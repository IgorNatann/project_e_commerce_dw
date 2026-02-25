-- ========================================
-- SCRIPT: 01_dim_data.sql
-- DESCRIÇÃO: Criação e população da DIM_DATA
-- AUTOR: Igor Natan
-- DATA: 2025-12-01
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
-- 4. POPULAR DIM_DATA (INTERVALO DINAMICO)
-- ========================================

PRINT 'Populando DIM_DATA com intervalo dinamico...';
PRINT '';

DECLARE @data_inicio DATE = '2020-01-01';
DECLARE @anos_futuros INT = 5;
DECLARE @data_fim DATE = DATEFROMPARTS(YEAR(GETDATE()) + @anos_futuros, 12, 31);
DECLARE @total_dias INT = DATEDIFF(DAY, @data_inicio, @data_fim) + 1;

PRINT 'Periodo: ' + CONVERT(VARCHAR(10), @data_inicio, 23) + ' ate ' + CONVERT(VARCHAR(10), @data_fim, 23);
PRINT 'Total de dias previstos: ' + CAST(@total_dias AS VARCHAR);
PRINT '';

-- Garantir mapeamento 1=Domingo ... 7=Sabado
SET DATEFIRST 7;

;WITH n AS (
    SELECT TOP (@total_dias)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS num
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
datas AS (
    SELECT DATEADD(DAY, n.num, @data_inicio) AS data_completa
    FROM n
),
anos AS (
    SELECT DISTINCT YEAR(data_completa) AS ano
    FROM datas
),
feriados AS (
    SELECT
        DATEFROMPARTS(a.ano, f.mes, f.dia) AS data,
        f.nome
    FROM anos a
    CROSS JOIN (VALUES
        (1, 1, 'Ano Novo'),
        (4, 21, 'Tiradentes'),
        (5, 1, 'Dia do Trabalho'),
        (9, 7, 'Independência'),
        (10, 12, 'N. Sra. Aparecida'),
        (11, 2, 'Finados'),
        (11, 15, 'Proclamação República'),
        (12, 25, 'Natal')
    ) f(mes, dia, nome)
)
INSERT INTO dim.DIM_DATA (
    data_completa, ano, trimestre, mes, dia,
    semana_do_ano, dia_da_semana,
    nome_mes, nome_mes_abrev,
    nome_dia_semana, nome_dia_semana_abrev,
    eh_fim_de_semana, eh_feriado, nome_feriado,
    dia_do_ano, eh_ano_bissexto,
    periodo_mes, periodo_trimestre
)
SELECT
    d.data_completa,
    YEAR(d.data_completa) AS ano,
    DATEPART(QUARTER, d.data_completa) AS trimestre,
    MONTH(d.data_completa) AS mes,
    DAY(d.data_completa) AS dia,
    DATEPART(WEEK, d.data_completa) AS semana_do_ano,
    DATEPART(WEEKDAY, d.data_completa) AS dia_da_semana,
    CASE MONTH(d.data_completa)
        WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
    END AS nome_mes,
    CASE MONTH(d.data_completa)
        WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
        WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
        WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
        WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
    END AS nome_mes_abrev,
    CASE DATEPART(WEEKDAY, d.data_completa)
        WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Segunda-feira' WHEN 3 THEN 'Terça-feira'
        WHEN 4 THEN 'Quarta-feira' WHEN 5 THEN 'Quinta-feira' WHEN 6 THEN 'Sexta-feira'
        WHEN 7 THEN 'Sábado'
    END AS nome_dia_semana,
    CASE DATEPART(WEEKDAY, d.data_completa)
        WHEN 1 THEN 'Dom' WHEN 2 THEN 'Seg' WHEN 3 THEN 'Ter'
        WHEN 4 THEN 'Qua' WHEN 5 THEN 'Qui' WHEN 6 THEN 'Sex'
        WHEN 7 THEN 'Sáb'
    END AS nome_dia_semana_abrev,
    CASE WHEN DATEPART(WEEKDAY, d.data_completa) IN (1, 7) THEN 1 ELSE 0 END AS eh_fim_de_semana,
    CASE WHEN f.data IS NULL THEN 0 ELSE 1 END AS eh_feriado,
    f.nome AS nome_feriado,
    DATEPART(DAYOFYEAR, d.data_completa) AS dia_do_ano,
    CASE
        WHEN (YEAR(d.data_completa) % 4 = 0 AND YEAR(d.data_completa) % 100 <> 0)
          OR (YEAR(d.data_completa) % 400 = 0)
        THEN 1 ELSE 0
    END AS eh_ano_bissexto,
    CONCAT(YEAR(d.data_completa), '-', RIGHT('0' + CAST(MONTH(d.data_completa) AS VARCHAR(2)), 2)) AS periodo_mes,
    CONCAT(YEAR(d.data_completa), '-Q', DATEPART(QUARTER, d.data_completa)) AS periodo_trimestre
FROM datas d
LEFT JOIN feriados f
    ON f.data = d.data_completa
ORDER BY d.data_completa;

PRINT '';
PRINT '✅ DIM_DATA populada com ' + CAST(@@ROWCOUNT AS VARCHAR) + ' registros!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO (Extended Properties)
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão Temporal - Hierarquia de datas de 2020 até ano atual + 5 com feriados fixos nacionais do Brasil.',
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
