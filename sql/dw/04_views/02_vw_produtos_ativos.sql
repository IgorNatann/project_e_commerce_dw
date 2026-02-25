-- ========================================
-- SCRIPT: 02_vw_produtos_ativos.sql
-- DESCRIÇÃO: View que retorna apenas produtos ativos
-- DEPENDÊNCIA: dim.DIM_PRODUTO deve existir
-- PROPÓSITO: Facilitar queries que trabalham apenas com produtos disponíveis
-- CASOS DE USO:
--   - Listar produtos disponíveis para venda
--   - Análise de margem por categoria/fornecedor
--   - Catálogo de produtos para relatórios
--   - Validações de integridade
-- AUTOR: Igor Natan
-- DATA: 2025-12-06
-- ========================================

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO: VW_PRODUTOS_ATIVOS';
PRINT '========================================';
PRINT '';

-- Dropar se existir
IF OBJECT_ID('dim.VW_PRODUTOS_ATIVOS', 'V') IS NOT NULL
BEGIN
    DROP VIEW dim.VW_PRODUTOS_ATIVOS;
    PRINT '⚠️  View existente foi dropada.';
END
GO

-- Criar view
CREATE VIEW dim.VW_PRODUTOS_ATIVOS
AS
SELECT 
    -- Identificadores
    produto_id,
    produto_original_id,
    codigo_sku,
    
    -- Informações do produto
    nome_produto,
    marca,
    
    -- Hierarquia de categorização
    categoria,
    subcategoria,
    
    -- Fornecedor
    fornecedor_id,
    nome_fornecedor,
    
    -- Atributos físicos
    peso_kg,
    CASE
        WHEN altura_cm IS NOT NULL AND largura_cm IS NOT NULL AND profundidade_cm IS NOT NULL
            THEN CONCAT(CAST(altura_cm AS VARCHAR(10)), 'x', CAST(largura_cm AS VARCHAR(10)), 'x', CAST(profundidade_cm AS VARCHAR(10)), ' cm')
        ELSE NULL
    END AS dimensoes,
    
    -- Atributos financeiros
    preco_sugerido,
    preco_custo AS custo_medio,
    
    -- ============ CAMPOS CALCULADOS ============
    
    -- Margem de lucro sugerida (percentual)
    CASE 
        WHEN preco_sugerido > 0 THEN 
            CAST(((preco_sugerido - preco_custo) / preco_sugerido * 100) AS DECIMAL(5,2))
        ELSE 0
    END AS margem_sugerida,
    
    -- Markup (quanto % acima do custo)
    CASE 
        WHEN preco_custo > 0 THEN 
            CAST(((preco_sugerido - preco_custo) / preco_custo * 100) AS DECIMAL(5,2))
        ELSE 0
    END AS markup_percentual,
    
    -- Hierarquia completa para drill-down
    CONCAT(categoria, ' > ', subcategoria, ' > ', nome_produto) AS hierarquia_completa,
    
    -- Classificação por preço
    CASE 
        WHEN preco_sugerido > 5000 THEN 'Premium (>5k)'
        WHEN preco_sugerido > 1000 THEN 'Alto (1k-5k)'
        WHEN preco_sugerido > 100 THEN 'Médio (100-1k)'
        ELSE 'Baixo (<100)'
    END AS faixa_preco,
    
    -- Data de cadastro
    data_cadastro,
    data_ultima_atualizacao

FROM dim.DIM_PRODUTO
WHERE situacao = 'Ativo';  -- APENAS PRODUTOS ATIVOS
GO

PRINT '✅ View dim.VW_PRODUTOS_ATIVOS criada!';
PRINT '';

-- Adicionar documentação
EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'View que retorna apenas produtos ativos com hierarquia de categorização e campos calculados de margem/markup.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'VIEW', @level1name = 'VW_PRODUTOS_ATIVOS';
GO

-- Teste de validação
PRINT 'Teste: Top 5 produtos por margem';
SELECT TOP 5
    nome_produto,
    categoria,
    preco_sugerido,
    custo_medio,
    margem_sugerida,
    faixa_preco
FROM dim.VW_PRODUTOS_ATIVOS
ORDER BY margem_sugerida DESC;
GO

PRINT '✅ View validada com sucesso!';
PRINT '';
