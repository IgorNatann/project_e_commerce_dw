-- ========================================
-- SCRIPT: 01_dim_data.sql
-- OBJETIVO: criar/atualizar DIM_DATA de forma idempotente
-- BASE: DW_ECOMMERCE
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'DIM_DATA - MODO IDEMPOTENTE';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1) CRIAR TABELA APENAS SE NAO EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_DATA', 'U') IS NULL
BEGIN
    PRINT 'Criando tabela dim.DIM_DATA...';

    CREATE TABLE dim.DIM_DATA
    (
        data_id INT IDENTITY(1,1) NOT NULL,
        data_completa DATE NOT NULL,
        ano INT NOT NULL,
        trimestre INT NOT NULL,
        mes INT NOT NULL,
        dia INT NOT NULL,
        semana_do_ano INT NOT NULL,
        dia_da_semana INT NOT NULL,
        nome_mes VARCHAR(20) NOT NULL,
        nome_mes_abrev VARCHAR(3) NOT NULL,
        nome_dia_semana VARCHAR(20) NOT NULL,
        nome_dia_semana_abrev VARCHAR(3) NOT NULL,
        eh_fim_de_semana BIT NOT NULL,
        eh_feriado BIT NOT NULL,
        nome_feriado VARCHAR(50) NULL,
        dia_do_ano INT NOT NULL,
        eh_ano_bissexto BIT NOT NULL,
        periodo_mes VARCHAR(7) NOT NULL,
        periodo_trimestre VARCHAR(7) NOT NULL,

        CONSTRAINT PK_DIM_DATA PRIMARY KEY CLUSTERED (data_id),
        CONSTRAINT UK_DIM_DATA_data_completa UNIQUE (data_completa),
        CONSTRAINT CK_DIM_DATA_trimestre CHECK (trimestre BETWEEN 1 AND 4),
        CONSTRAINT CK_DIM_DATA_mes CHECK (mes BETWEEN 1 AND 12),
        CONSTRAINT CK_DIM_DATA_dia CHECK (dia BETWEEN 1 AND 31)
    );

    PRINT 'Tabela dim.DIM_DATA criada.';
END
ELSE
BEGIN
    PRINT 'Tabela dim.DIM_DATA ja existe. Validando contrato...';

    DECLARE @missing_columns NVARCHAR(MAX);
    ;WITH required_columns AS
    (
        SELECT column_name
        FROM (VALUES
            ('data_id'),
            ('data_completa'),
            ('ano'),
            ('trimestre'),
            ('mes'),
            ('dia'),
            ('semana_do_ano'),
            ('dia_da_semana'),
            ('nome_mes'),
            ('nome_mes_abrev'),
            ('nome_dia_semana'),
            ('nome_dia_semana_abrev'),
            ('eh_fim_de_semana'),
            ('eh_feriado'),
            ('nome_feriado'),
            ('dia_do_ano'),
            ('eh_ano_bissexto'),
            ('periodo_mes'),
            ('periodo_trimestre')
        ) AS v(column_name)
    )
    SELECT @missing_columns = STRING_AGG(rc.column_name, ', ')
    FROM required_columns rc
    WHERE COL_LENGTH('dim.DIM_DATA', rc.column_name) IS NULL;

    IF @missing_columns IS NOT NULL
    BEGIN
        RAISERROR('dim.DIM_DATA sem colunas obrigatorias: %s', 16, 1, @missing_columns);
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints kc
        WHERE kc.parent_object_id = OBJECT_ID('dim.DIM_DATA')
          AND kc.name = 'UK_DIM_DATA_data_completa'
          AND kc.type = 'UQ'
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dim.DIM_DATA
            GROUP BY data_completa
            HAVING COUNT(*) > 1
        )
        BEGIN
            RAISERROR('Nao foi possivel criar UK_DIM_DATA_data_completa: existem datas duplicadas.', 16, 1);
            RETURN;
        END;

        ALTER TABLE dim.DIM_DATA
        ADD CONSTRAINT UK_DIM_DATA_data_completa UNIQUE (data_completa);
    END;
END
GO

-- ========================================
-- 2) GARANTIR INDICES
-- ========================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_DATA')
      AND name = 'IX_DIM_DATA_data_completa'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_DATA_data_completa
        ON dim.DIM_DATA(data_completa)
        INCLUDE (ano, mes, trimestre);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_DATA')
      AND name = 'IX_DIM_DATA_ano_mes'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_DATA_ano_mes
        ON dim.DIM_DATA(ano, mes)
        INCLUDE (data_completa);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dim.DIM_DATA')
      AND name = 'IX_DIM_DATA_ano_trimestre'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DIM_DATA_ano_trimestre
        ON dim.DIM_DATA(ano, trimestre);
END;
GO

-- ========================================
-- 3) DEFINIR JANELA DE CARGA
-- ========================================
DECLARE @default_start DATE = '2020-01-01';
DECLARE @future_years INT = 5;
DECLARE @default_end DATE = DATEFROMPARTS(YEAR(GETDATE()) + @future_years, 12, 31);

DECLARE @existing_min DATE;
DECLARE @existing_max DATE;
DECLARE @source_min DATE;
DECLARE @source_max DATE;

SELECT
    @existing_min = MIN(data_completa),
    @existing_max = MAX(data_completa)
FROM dim.DIM_DATA;

IF DB_ID('ECOMMERCE_OLTP') IS NOT NULL
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'
    IF OBJECT_ID(''ECOMMERCE_OLTP.core.orders'', ''U'') IS NOT NULL
    BEGIN
        SELECT
            @source_min_out = MIN(CAST(order_date AS DATE)),
            @source_max_out = MAX(CAST(order_date AS DATE))
        FROM ECOMMERCE_OLTP.core.orders;
    END;';

    EXEC sp_executesql
        @sql,
        N'@source_min_out DATE OUTPUT, @source_max_out DATE OUTPUT',
        @source_min_out = @source_min OUTPUT,
        @source_max_out = @source_max OUTPUT;
END;

DECLARE @data_inicio DATE = @default_start;
DECLARE @data_fim DATE = @default_end;

IF @source_min IS NOT NULL AND @source_min < @data_inicio
    SET @data_inicio = @source_min;
IF @existing_min IS NOT NULL AND @existing_min < @data_inicio
    SET @data_inicio = @existing_min;

IF @source_max IS NOT NULL AND @source_max > @data_fim
    SET @data_fim = @source_max;
IF @existing_max IS NOT NULL AND @existing_max > @data_fim
    SET @data_fim = @existing_max;

DECLARE @total_dias INT = DATEDIFF(DAY, @data_inicio, @data_fim) + 1;

PRINT 'Intervalo alvo DIM_DATA:';
PRINT ' - inicio: ' + CONVERT(VARCHAR(10), @data_inicio, 23);
PRINT ' - fim:    ' + CONVERT(VARCHAR(10), @data_fim, 23);
PRINT ' - dias:   ' + CAST(@total_dias AS VARCHAR(20));
PRINT '';

-- ========================================
-- 4) INSERIR APENAS DATAS FALTANTES
-- ========================================
SET DATEFIRST 7; -- 1=domingo

;WITH n AS
(
    SELECT TOP (@total_dias)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS num
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
datas AS
(
    SELECT DATEADD(DAY, n.num, @data_inicio) AS data_completa
    FROM n
),
anos AS
(
    SELECT DISTINCT YEAR(data_completa) AS ano
    FROM datas
),
feriados AS
(
    SELECT
        DATEFROMPARTS(a.ano, f.mes, f.dia) AS data,
        f.nome
    FROM anos a
    CROSS JOIN (VALUES
        (1, 1, 'Ano Novo'),
        (4, 21, 'Tiradentes'),
        (5, 1, 'Dia do Trabalho'),
        (9, 7, 'Independencia'),
        (10, 12, 'N. Sra. Aparecida'),
        (11, 2, 'Finados'),
        (11, 15, 'Proclamacao Republica'),
        (12, 25, 'Natal')
    ) f(mes, dia, nome)
)
INSERT INTO dim.DIM_DATA
(
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
        WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Marco'
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
        WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Segunda-feira' WHEN 3 THEN 'Terca-feira'
        WHEN 4 THEN 'Quarta-feira' WHEN 5 THEN 'Quinta-feira' WHEN 6 THEN 'Sexta-feira'
        WHEN 7 THEN 'Sabado'
    END AS nome_dia_semana,
    CASE DATEPART(WEEKDAY, d.data_completa)
        WHEN 1 THEN 'Dom' WHEN 2 THEN 'Seg' WHEN 3 THEN 'Ter'
        WHEN 4 THEN 'Qua' WHEN 5 THEN 'Qui' WHEN 6 THEN 'Sex'
        WHEN 7 THEN 'Sab'
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
WHERE NOT EXISTS
(
    SELECT 1
    FROM dim.DIM_DATA x
    WHERE x.data_completa = d.data_completa
)
ORDER BY d.data_completa;

DECLARE @inserted_rows INT = @@ROWCOUNT;
PRINT 'Linhas inseridas nesta execucao: ' + CAST(@inserted_rows AS VARCHAR(20));
PRINT '';

-- ========================================
-- 5) VALIDACOES RAPIDAS
-- ========================================
PRINT 'Resumo DIM_DATA:';
SELECT
    COUNT(*) AS total_registros,
    MIN(data_completa) AS min_data,
    MAX(data_completa) AS max_data,
    SUM(CASE WHEN eh_feriado = 1 THEN 1 ELSE 0 END) AS total_feriados,
    SUM(CASE WHEN eh_fim_de_semana = 1 THEN 1 ELSE 0 END) AS total_fins_semana
FROM dim.DIM_DATA;

PRINT '';
PRINT 'DIM_DATA pronta (idempotente).';
GO
