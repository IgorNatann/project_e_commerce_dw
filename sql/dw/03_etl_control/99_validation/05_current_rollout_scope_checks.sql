-- ========================================
-- SCRIPT: 05_current_rollout_scope_checks.sql
-- OBJETIVO: validar rollout atual apos bootstrap da stack
-- ========================================

USE DW_ECOMMERCE;
GO

SET NOCOUNT ON;
GO

DECLARE @errors TABLE
(
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    error_message NVARCHAR(4000) NOT NULL
);

-- Estruturas obrigatorias para o rollout atual.
IF OBJECT_ID('ctl.etl_control', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela ctl.etl_control nao encontrada.');

IF OBJECT_ID('dim.DIM_DATA', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_DATA nao encontrada.');
IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_CLIENTE nao encontrada.');
IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_PRODUTO nao encontrada.');
IF OBJECT_ID('dim.DIM_REGIAO', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_REGIAO nao encontrada.');
IF OBJECT_ID('dim.DIM_EQUIPE', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_EQUIPE nao encontrada.');
IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_VENDEDOR nao encontrada.');
IF OBJECT_ID('dim.DIM_DESCONTO', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela dim.DIM_DESCONTO nao encontrada.');
IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela fact.FACT_VENDAS nao encontrada.');
IF OBJECT_ID('fact.FACT_METAS', 'U') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Tabela fact.FACT_METAS nao encontrada.');

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NOT NULL
AND COL_LENGTH('fact.FACT_VENDAS', 'venda_original_id') IS NULL
    INSERT INTO @errors(error_message) VALUES ('Coluna fact.FACT_VENDAS.venda_original_id nao encontrada.');

IF OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL
BEGIN
    DECLARE @expected_active TABLE (entity_name VARCHAR(100) PRIMARY KEY);
    DECLARE @expected_inactive TABLE (entity_name VARCHAR(100) PRIMARY KEY);

    INSERT INTO @expected_active(entity_name)
    VALUES
        ('dim_cliente'),
        ('dim_produto'),
        ('dim_regiao'),
        ('dim_equipe'),
        ('dim_vendedor'),
        ('dim_desconto'),
        ('fact_vendas'),
        ('fact_metas');

    INSERT INTO @expected_inactive(entity_name)
    VALUES
        ('fact_descontos');

    INSERT INTO @errors(error_message)
    SELECT CONCAT('Entidade ativa esperada nao encontrada no ctl.etl_control: ', ea.entity_name)
    FROM @expected_active AS ea
    LEFT JOIN ctl.etl_control AS c
        ON c.entity_name = ea.entity_name
    WHERE c.entity_name IS NULL;

    INSERT INTO @errors(error_message)
    SELECT CONCAT('Entidade inativa esperada nao encontrada no ctl.etl_control: ', ei.entity_name)
    FROM @expected_inactive AS ei
    LEFT JOIN ctl.etl_control AS c
        ON c.entity_name = ei.entity_name
    WHERE c.entity_name IS NULL;

    INSERT INTO @errors(error_message)
    SELECT CONCAT('Entidade deveria estar ativa, mas is_active <> 1: ', c.entity_name)
    FROM ctl.etl_control AS c
    INNER JOIN @expected_active AS ea
        ON ea.entity_name = c.entity_name
    WHERE c.is_active <> 1;

    INSERT INTO @errors(error_message)
    SELECT CONCAT('Entidade deveria estar inativa, mas is_active <> 0: ', c.entity_name)
    FROM ctl.etl_control AS c
    INNER JOIN @expected_inactive AS ei
        ON ei.entity_name = c.entity_name
    WHERE c.is_active <> 0;

    INSERT INTO @errors(error_message)
    SELECT CONCAT('Entidade ativa fora do rollout atual: ', c.entity_name)
    FROM ctl.etl_control AS c
    LEFT JOIN @expected_active AS ea
        ON ea.entity_name = c.entity_name
    WHERE c.is_active = 1
      AND ea.entity_name IS NULL;
END;

PRINT 'Resumo do escopo atual em ctl.etl_control:';
SELECT
    entity_name,
    source_table,
    target_table,
    source_pk_column,
    batch_size,
    cutoff_minutes,
    is_active
FROM ctl.etl_control
ORDER BY entity_name;

IF EXISTS (SELECT 1 FROM @errors)
BEGIN
    PRINT '';
    PRINT 'Falhas detectadas na validacao de rollout:';
    SELECT error_id, error_message
    FROM @errors
    ORDER BY error_id;

    RAISERROR('Rollout atual invalido. Corrija os erros e execute novamente.', 16, 1);
    RETURN;
END;

PRINT '';
PRINT 'Validacao de rollout concluida com sucesso.';
GO
