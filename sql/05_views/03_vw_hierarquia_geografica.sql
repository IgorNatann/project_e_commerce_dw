-- ========================================
-- SCRIPT: 03_vw_hierarquia_geografica.sql
-- DESCRIÇÃO: View com hierarquia geográfica completa
-- DEPENDÊNCIA: dim.DIM_REGIAO deve existir
-- PROPÓSITO: Simplificar análises geográficas e drill-down por localização
-- CASOS DE USO:
--   - Análise de vendas por região do país
--   - Comparação entre capitais e interior
--   - Correlação entre IDH/PIB e volume de vendas
--   - Drill-down geográfico em dashboards
-- AUTOR: Igor Natan
-- DATA: 2025-12-06
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO: VW_HIERARQUIA_GEOGRAFICA';
PRINT '========================================';
PRINT '';

-- Dropar se existir
IF OBJECT_ID('dim.VW_HIERARQUIA_GEOGRAFICA', 'V') IS NOT NULL
BEGIN
    DROP VIEW dim.VW_HIERARQUIA_GEOGRAFICA;
    PRINT '⚠️  View existente foi dropada.';
END
GO

-- Criar view
CREATE VIEW dim.VW_HIERARQUIA_GEOGRAFICA
AS
SELECT 
    -- Identificadores
    regiao_id,
    regiao_original_id,
    
    -- Hierarquia geográfica (do mais amplo ao mais específico)
    pais,
    regiao_pais,
    estado,
    nome_estado,
    cidade,
    
    -- Códigos de referência
    codigo_ibge,
    cep_inicial,
    cep_final,
    ddd,
    
    -- Classificação do município
    tipo_municipio,
    porte_municipio,
    
    -- Dados demográficos
    populacao_estimada,
    area_km2,
    densidade_demografica,
    
    -- Indicadores econômicos/sociais
    pib_per_capita,
    idh,
    
    -- Localização geográfica
    latitude,
    longitude,
    fuso_horario,
    
    -- ============ CAMPOS CALCULADOS ============
    
    -- Hierarquia completa para drill-down
    CONCAT(pais, ' > ', regiao_pais, ' > ', estado, ' > ', cidade) AS hierarquia_completa,
    
    -- Classificação por tamanho populacional
    CASE 
        WHEN populacao_estimada > 1000000 THEN 'Metrópole (>1M)'
        WHEN populacao_estimada > 500000 THEN 'Grande (500k-1M)'
        WHEN populacao_estimada > 100000 THEN 'Médio (100k-500k)'
        ELSE 'Pequeno (<100k)'
    END AS classificacao_populacional,
    
    -- Classificação de IDH
    CASE 
        WHEN idh >= 0.800 THEN 'Muito Alto (≥0.800)'
        WHEN idh >= 0.700 THEN 'Alto (0.700-0.799)'
        WHEN idh >= 0.600 THEN 'Médio (0.600-0.699)'
        ELSE 'Baixo (<0.600)'
    END AS classificacao_idh,
    
    -- É capital?
    CASE 
        WHEN tipo_municipio = 'Capital' THEN 1 
        ELSE 0 
    END AS eh_capital,
    
    -- Sigla estado + DDD (para identificação rápida)
    CONCAT(estado, '-', ddd) AS codigo_estado_ddd

FROM dim.DIM_REGIAO
WHERE eh_ativo = 1;  -- APENAS REGIÕES ATIVAS
GO

PRINT '✅ View dim.VW_HIERARQUIA_GEOGRAFICA criada!';
PRINT '';

-- Adicionar documentação
EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'View com hierarquia geográfica completa (País > Região > Estado > Cidade) e classificações demográficas.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'VIEW', @level1name = 'VW_HIERARQUIA_GEOGRAFICA';
GO

-- Teste de validação
PRINT 'Teste: Distribuição de cidades por região';
SELECT 
    regiao_pais,
    COUNT(*) AS total_cidades,
    SUM(populacao_estimada) AS populacao_total,
    AVG(pib_per_capita) AS pib_medio,
    AVG(idh) AS idh_medio
FROM dim.VW_HIERARQUIA_GEOGRAFICA
WHERE regiao_pais IS NOT NULL
GROUP BY regiao_pais
ORDER BY populacao_total DESC;
GO

PRINT '✅ View validada com sucesso!';
PRINT '';