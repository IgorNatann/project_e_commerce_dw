-- ========================================
-- SCRIPT: 01_vw_calendario_completo.sql
-- DESCRIÇÃO: View auxiliar da DIM_DATA com campos calculados
-- DEPENDÊNCIA: dim.DIM_DATA deve existir
-- PROPÓSITO: Simplificar queries temporais e análises de sazonalidade
-- CASOS DE USO:
--   - Filtrar apenas dias úteis
--   - Comparar performance entre trimestres
--   - Análise de sazonalidade (feriados, fins de semana)
--   - Drill-down temporal: Ano → Trimestre → Mês → Dia
-- AUTOR: Igor Natan
-- DATA: 2025-12-06
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO: VW_CALENDARIO_COMPLETO';
PRINT '========================================';
PRINT '';

-- Dropar se existir
IF OBJECT_ID('dim.VW_CALENDARIO_COMPLETO', 'V') IS NOT NULL
BEGIN
    DROP VIEW dim.VW_CALENDARIO_COMPLETO;
    PRINT '⚠️  View existente foi dropada.';
END
GO

-- Criar view
CREATE VIEW dim.VW_CALENDARIO_COMPLETO
AS
SELECT 
    -- Chaves e datas
    data_id,
    data_completa,
    
    -- Hierarquia temporal
    ano,
    trimestre,
    mes,
    nome_mes,
    dia_semana,
    nome_dia_semana,
    
    -- Flags de classificação
    eh_fim_de_semana,
    eh_feriado,
    nome_feriado,
    
    -- ============ CAMPOS CALCULADOS ============
    
    -- É dia útil? (não é fim de semana nem feriado)
    CASE 
        WHEN eh_fim_de_semana = 0 AND eh_feriado = 0 THEN 1 
        ELSE 0 
    END AS eh_dia_util,
    
    -- Período descritivo para relatórios
    CASE 
        WHEN trimestre IS NOT NULL THEN 
            'Q' + CAST(trimestre AS VARCHAR(1)) + ' ' + CAST(ano AS VARCHAR(4))
        ELSE 
            nome_mes + '/' + CAST(ano AS VARCHAR(4))
    END AS periodo_desc,
    
    -- Semana do ano (1-52)
    DATEPART(WEEK, data_completa) AS semana_ano,
    
    -- Dia do ano (1-365)
    DATEPART(DAYOFYEAR, data_completa) AS dia_ano,
    
    -- Número de dias no mês
    DAY(EOMONTH(data_completa)) AS dias_no_mes,
    
    -- É último dia do mês?
    CASE 
        WHEN data_completa = EOMONTH(data_completa) THEN 1 
        ELSE 0 
    END AS eh_ultimo_dia_mes

FROM dim.DIM_DATA;
GO

PRINT '✅ View dim.VW_CALENDARIO_COMPLETO criada!';
PRINT '';

-- Adicionar documentação
EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'View auxiliar da dimensão temporal com campos calculados para análises de sazonalidade e drill-down temporal.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'VIEW', @level1name = 'VW_CALENDARIO_COMPLETO';
GO

-- Teste de validação
PRINT 'Teste: Dias úteis vs fins de semana em 2024';
SELECT 
    eh_dia_util,
    CASE WHEN eh_dia_util = 1 THEN 'Dia Útil' ELSE 'Fim de Semana/Feriado' END AS tipo,
    COUNT(*) AS total_dias
FROM dim.VW_CALENDARIO_COMPLETO
WHERE ano = 2024
GROUP BY eh_dia_util;
GO

PRINT '✅ View validada com sucesso!';
PRINT '';