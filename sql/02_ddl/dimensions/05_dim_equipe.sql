-- ========================================
-- SCRIPT: 05_dim_equipe.sql
-- DESCRIÇÃO: Criação da DIM_EQUIPE
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2025-12-06
-- PRÉ-REQUISITO: 04_dim_regiao.sql executado
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA DIM_EQUIPE                                             ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta dimensão armazena informações sobre EQUIPES DE VENDAS.          ║
║  Vendedores pertencem a equipes, e precisamos analisar:               ║
║                                                                        ║
║  ✅ Performance de equipes inteiras                                    ║
║  ✅ Comparação entre regionais                                         ║
║  ✅ Atingimento de metas coletivas                                     ║
║  ✅ Hierarquia de liderança                                            ║
║                                                                        ║
║  📊 RELACIONAMENTOS:                                                   ║
║  • DIM_VENDEDOR → DIM_EQUIPE (N:1)                                     ║
║  • FACT_VENDAS → DIM_VENDEDOR → DIM_EQUIPE (transitivo)               ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_EQUIPE';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_EQUIPE', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_EQUIPE;
    PRINT '⚠️  Tabela dim.DIM_EQUIPE existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_EQUIPE
-- ========================================

PRINT 'Criando tabela dim.DIM_EQUIPE...';
PRINT '';

CREATE TABLE dim.DIM_EQUIPE
(
    -- ============================================
    -- CHAVE PRIMÁRIA (Surrogate Key)
    -- ============================================
    -- Por que INT IDENTITY?
    -- • Independente do sistema origem
    -- • Facilita joins (mais rápido que VARCHAR)
    -- • Nunca muda mesmo se dados externos mudarem
    -- ============================================
    equipe_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============================================
    -- NATURAL KEY (Chave do Sistema Origem)
    -- ============================================
    -- Por que manter?
    -- • Rastreabilidade com sistema transacional
    -- • Processos ETL precisam dessa referência
    -- • Troubleshooting e auditoria
    -- ============================================
    equipe_original_id INT NOT NULL,
    
    -- ============================================
    -- IDENTIFICAÇÃO DA EQUIPE
    -- ============================================
    nome_equipe VARCHAR(100) NOT NULL,
    -- Exemplo: "Equipe Alpha SP", "Time Beta RJ"
    
    codigo_equipe VARCHAR(20) NULL,
    -- Exemplo: "EQ-SP-01", "TM-RJ-02"
    -- Código interno usado pela empresa
    
    -- ============================================
    -- CLASSIFICAÇÃO
    -- ============================================
    tipo_equipe VARCHAR(30) NULL,
    -- Por que esse campo?
    -- • Diferentes tipos têm diferentes estratégias
    -- Valores possíveis:
    --   - 'Vendas Diretas'
    --   - 'Inside Sales' (vendas remotas)
    --   - 'Key Accounts' (grandes clientes)
    --   - 'Varejo'
    --   - 'E-commerce'
    -- ============================================
    
    categoria_equipe VARCHAR(30) NULL,
    -- Classificação de performance histórica:
    --   - 'Elite' (top performers)
    --   - 'Avançado'
    --   - 'Intermediário'
    --   - 'Iniciante'
    -- Útil para benchmarking
    
    -- ============================================
    -- LOCALIZAÇÃO GEOGRÁFICA
    -- ============================================
    -- Por que localização na equipe?
    -- • Equipes geralmente têm território fixo
    -- • Permite análise: "Região X vs Região Y"
    -- • Facilita queries sem precisar ir até FACT
    -- ============================================
    regional VARCHAR(50) NULL,
    -- Exemplo: "Sul", "Sudeste", "Nordeste"
    -- Região de atuação da equipe
    
    estado_sede CHAR(2) NULL,
    -- Estado onde fica o escritório da equipe
    -- Exemplo: "SP", "RJ", "MG"
    
    cidade_sede VARCHAR(100) NULL,
    -- Cidade da sede da equipe
    
    -- ============================================
    -- HIERARQUIA / LIDERANÇA
    -- ============================================
    -- Por que armazenar líder aqui?
    -- • Facilita relatórios de gestão
    -- • Evita self-join complexo na DIM_VENDEDOR
    -- ATENÇÃO: Este é o VENDEDOR que lidera a equipe
    -- ============================================
    lider_equipe_id INT NULL,
    -- FK para DIM_VENDEDOR (será criada depois)
    -- NULL = equipe sem líder atribuído ainda
    
    nome_lider VARCHAR(150) NULL,
    -- DESNORMALIZADO propositalmente!
    -- Por quê? Performance em relatórios
    -- Líder muda raramente, então é seguro
    
    email_lider VARCHAR(255) NULL,
    -- Contato do líder da equipe
    
    -- ============================================
    -- METAS E OBJETIVOS
    -- ============================================
    -- Por que meta aqui e não em FACT_METAS?
    -- • Esta é a meta PADRÃO mensal da equipe
    -- • FACT_METAS terá metas REALIZADAS por período
    -- • Este campo é "o objetivo", fact é "o resultado"
    -- ============================================
    meta_mensal_equipe DECIMAL(15,2) NULL,
    -- Meta de vendas em R$ por mês
    -- Exemplo: 500000.00 = R$ 500 mil/mês
    
    meta_trimestral_equipe DECIMAL(15,2) NULL,
    -- Meta trimestral (geralmente meta_mensal * 3)
    
    meta_anual_equipe DECIMAL(15,2) NULL,
    -- Meta do ano (pode ser diferente de mensal*12)
    -- devido a sazonalidade
    
    qtd_meta_vendas_mes INT NULL,
    -- Meta de QUANTIDADE de vendas por mês
    -- Exemplo: 150 vendas/mês
    
    -- ============================================
    -- COMPOSIÇÃO DA EQUIPE
    -- ============================================
    qtd_membros_atual INT NULL,
    -- Quantos vendedores tem AGORA na equipe?
    -- Atualizado periodicamente no ETL
    
    qtd_membros_ideal INT NULL,
    -- Quantos vendedores a equipe DEVERIA ter?
    -- Para análise de capacidade
    
    -- ============================================
    -- PERFORMANCE HISTÓRICA (Snapshot)
    -- ============================================
    -- Por que armazenar histórico aqui?
    -- • Para comparações rápidas sem calcular
    -- • Atualizado mensalmente pelo ETL
    -- ATENÇÃO: Dados reais estão na FACT_VENDAS!
    -- ============================================
    total_vendas_mes_anterior DECIMAL(15,2) NULL,
    -- Total vendido no último mês fechado
    
    percentual_meta_mes_anterior DECIMAL(5,2) NULL,
    -- % da meta atingida no último mês
    -- Exemplo: 105.50 = bateu 105.5% da meta
    
    ranking_ultimo_mes INT NULL,
    -- Posição da equipe no ranking mensal
    -- 1 = melhor equipe do mês
    
    -- ============================================
    -- DATAS DE CONTROLE
    -- ============================================
    data_criacao DATE NOT NULL,
    -- Quando a equipe foi formada
    
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Última vez que este registro foi modificado
    
    data_inativacao DATE NULL,
    -- Se equipe foi desfeita, quando foi?
    
    -- ============================================
    -- STATUS E FLAGS
    -- ============================================
    situacao VARCHAR(20) NOT NULL DEFAULT 'Ativa',
    -- Valores possíveis:
    --   - 'Ativa' (operando normalmente)
    --   - 'Inativa' (desfeita)
    --   - 'Suspensa' (temporariamente parada)
    --   - 'Em Formação' (sendo montada)
    
    eh_ativa BIT NOT NULL DEFAULT 1,
    -- 0 = Inativa, 1 = Ativa
    -- Campo booleano para filtros rápidos
    
    -- ============================================
    -- OBSERVAÇÕES
    -- ============================================
    observacoes VARCHAR(500) NULL,
    -- Notas sobre a equipe
    -- Exemplo: "Equipe especializada em clientes corporativos"
    
    -- ============================================
    -- CONSTRAINTS (Regras de Integridade)
    -- ============================================
    
    -- Primary Key
    CONSTRAINT PK_DIM_EQUIPE 
        PRIMARY KEY CLUSTERED (equipe_id),
    
    -- Unique: Não pode ter 2 equipes com mesmo ID original
    CONSTRAINT UK_DIM_EQUIPE_original_id 
        UNIQUE (equipe_original_id),
    
    -- Unique: Não pode ter 2 equipes com mesmo nome
    CONSTRAINT UK_DIM_EQUIPE_nome 
        UNIQUE (nome_equipe),
    
    -- Check: Meta não pode ser negativa
    CONSTRAINT CK_DIM_EQUIPE_meta_positiva 
        CHECK (meta_mensal_equipe >= 0 OR meta_mensal_equipe IS NULL),
    
    -- Check: Quantidade de membros não pode ser negativa
    CONSTRAINT CK_DIM_EQUIPE_qtd_membros 
        CHECK (qtd_membros_atual >= 0 OR qtd_membros_atual IS NULL),
    
    -- Check: Situação deve ser um dos valores válidos
    CONSTRAINT CK_DIM_EQUIPE_situacao 
        CHECK (situacao IN ('Ativa', 'Inativa', 'Suspensa', 'Em Formação')),
    
    -- Check: Estado deve ter exatamente 2 caracteres
    CONSTRAINT CK_DIM_EQUIPE_estado 
        CHECK (LEN(estado_sede) = 2 OR estado_sede IS NULL)
);
GO

PRINT '✅ Tabela dim.DIM_EQUIPE criada com sucesso!';
PRINT '';
PRINT '📊 Estrutura:';
PRINT '   • Chave Primária: equipe_id (surrogate)';
PRINT '   • Chave Natural: equipe_original_id';
PRINT '   • Hierarquia: lider_equipe_id';
PRINT '   • Metas: mensal, trimestral, anual';
PRINT '   • Localização: regional, estado, cidade';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

/*
╔════════════════════════════════════════════════════════════════════════╗
║  📚 POR QUE CADA ÍNDICE?                                               ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Índices aceleram buscas mas ocupam espaço.                           ║
║  Criamos índices para os campos MAIS USADOS em queries.               ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

-- Índice 1: Busca por ID original (usado no ETL)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_original_id 
    ON dim.DIM_EQUIPE(equipe_original_id)
    INCLUDE (equipe_id, nome_equipe, situacao);
PRINT '  ✅ IX_DIM_EQUIPE_original_id';
PRINT '     Uso: Lookup no processo ETL';

-- Índice 2: Busca por regional (queries analíticas)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_regional 
    ON dim.DIM_EQUIPE(regional)
    INCLUDE (equipe_id, nome_equipe, meta_mensal_equipe)
    WHERE regional IS NOT NULL;
PRINT '  ✅ IX_DIM_EQUIPE_regional';
PRINT '     Uso: "Vendas por regional"';

-- Índice 3: Busca por situação (filtrar ativas)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_situacao 
    ON dim.DIM_EQUIPE(situacao, eh_ativa)
    INCLUDE (equipe_id, nome_equipe);
PRINT '  ✅ IX_DIM_EQUIPE_situacao';
PRINT '     Uso: Filtrar apenas equipes ativas';

-- Índice 4: Busca por líder (relatórios de gestão)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_lider 
    ON dim.DIM_EQUIPE(lider_equipe_id)
    INCLUDE (nome_equipe, meta_mensal_equipe)
    WHERE lider_equipe_id IS NOT NULL;
PRINT '  ✅ IX_DIM_EQUIPE_lider';
PRINT '     Uso: "Equipes do gestor X"';

-- Índice 5: Busca por tipo (análise por categoria)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_tipo 
    ON dim.DIM_EQUIPE(tipo_equipe)
    INCLUDE (equipe_id, nome_equipe)
    WHERE tipo_equipe IS NOT NULL;
PRINT '  ✅ IX_DIM_EQUIPE_tipo';
PRINT '     Uso: Comparar tipos de equipe';

-- Índice 6: Busca por nome (autocomplete, pesquisas)
CREATE NONCLUSTERED INDEX IX_DIM_EQUIPE_nome 
    ON dim.DIM_EQUIPE(nome_equipe)
    INCLUDE (equipe_id, tipo_equipe, regional);
PRINT '  ✅ IX_DIM_EQUIPE_nome';
PRINT '     Uso: Busca textual por nome';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO EQUIPES DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar 10 equipes cobrindo diferentes:
• Regiões do Brasil
• Tipos de venda
• Níveis de maturidade
*/

-- Equipe 1: Elite de São Paulo
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    1, 'Equipe Alpha SP', 'EQ-SP-01', 'Vendas Diretas', 'Elite',
    'Sudeste', 'SP', 'São Paulo',
    500000.00, 1500000.00, 6000000.00, 150,
    8, 10,
    '2023-01-15', 'Ativa', 1
);

-- Equipe 2: Inside Sales Rio
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    2, 'Time Beta RJ', 'EQ-RJ-01', 'Inside Sales', 'Avançado',
    'Sudeste', 'RJ', 'Rio de Janeiro',
    350000.00, 1050000.00, 4200000.00, 200,
    6, 8,
    '2023-03-10', 'Ativa', 1
);

-- Equipe 3: Key Accounts MG
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    3, 'Equipe Gamma MG', 'EQ-MG-01', 'Key Accounts', 'Elite',
    'Sudeste', 'MG', 'Belo Horizonte',
    800000.00, 2400000.00, 9600000.00, 50,
    5, 6,
    '2022-06-01', 'Ativa', 1
);

-- Equipe 4: Varejo Sul - RS
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    4, 'Time Delta RS', 'EQ-RS-01', 'Varejo', 'Intermediário',
    'Sul', 'RS', 'Porto Alegre',
    300000.00, 900000.00, 3600000.00, 180,
    7, 8,
    '2023-08-20', 'Ativa', 1
);

-- Equipe 5: E-commerce Nacional
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    5, 'Equipe Digital', 'EQ-DIG-01', 'E-commerce', 'Elite',
    'Nacional', 'SP', 'São Paulo',
    1000000.00, 3000000.00, 12000000.00, 500,
    12, 15,
    '2022-01-01', 'Ativa', 1
);

-- Equipe 6: Vendas Paraná
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    6, 'Time Epsilon PR', 'EQ-PR-01', 'Vendas Diretas', 'Avançado',
    'Sul', 'PR', 'Curitiba',
    400000.00, 1200000.00, 4800000.00, 120,
    6, 8,
    '2023-04-15', 'Ativa', 1
);

-- Equipe 7: Nordeste - BA
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    7, 'Equipe Zeta BA', 'EQ-BA-01', 'Vendas Diretas', 'Intermediário',
    'Nordeste', 'BA', 'Salvador',
    250000.00, 750000.00, 3000000.00, 100,
    5, 7,
    '2023-09-01', 'Ativa', 1
);

-- Equipe 8: Centro-Oeste
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    8, 'Time Theta GO', 'EQ-GO-01', 'Varejo', 'Iniciante',
    'Centro-Oeste', 'GO', 'Goiânia',
    200000.00, 600000.00, 2400000.00, 80,
    4, 6,
    '2024-01-10', 'Ativa', 1
);

-- Equipe 9: Em Formação - DF
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, situacao, eh_ativa
)
VALUES (
    9, 'Equipe Iota DF', 'EQ-DF-01', 'Vendas Diretas', 'Iniciante',
    'Centro-Oeste', 'DF', 'Brasília',
    150000.00, 450000.00, 1800000.00, 60,
    2, 5,
    '2024-11-01', 'Em Formação', 1
);

-- Equipe 10: Inativa (exemplo histórico)
INSERT INTO dim.DIM_EQUIPE (
    equipe_original_id, nome_equipe, codigo_equipe, tipo_equipe, categoria_equipe,
    regional, estado_sede, cidade_sede,
    meta_mensal_equipe, meta_trimestral_equipe, meta_anual_equipe, qtd_meta_vendas_mes,
    qtd_membros_atual, qtd_membros_ideal,
    data_criacao, data_inativacao, situacao, eh_ativa,
    observacoes
)
VALUES (
    10, 'Equipe Kappa SP (Inativa)', 'EQ-SP-99', 'Vendas Diretas', 'Intermediário',
    'Sudeste', 'SP', 'Campinas',
    300000.00, 900000.00, 3600000.00, 100,
    0, 6,
    '2022-01-01', '2023-12-31', 'Inativa', 0,
    'Equipe desfeita após reestruturação organizacional'
);

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' equipes inseridas!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação estendida...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão de Equipes de Vendas - Armazena informações sobre times comerciais, suas metas e hierarquia.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_EQUIPE';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Meta de vendas em R$ para o mês. Atualizada conforme planejamento comercial.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_EQUIPE',
    @level2type = N'COLUMN', @level2name = 'meta_mensal_equipe';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'FK para DIM_VENDEDOR - Indica quem é o líder/gestor desta equipe.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_EQUIPE',
    @level2type = N'COLUMN', @level2name = 'lider_equipe_id';

PRINT '✅ Documentação adicionada!';
PRINT '';

-- ========================================
-- 6. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- 1. Total de equipes
PRINT '1. Total de Equipes Cadastradas:';
SELECT 
    COUNT(*) AS total_equipes,
    SUM(CASE WHEN eh_ativa = 1 THEN 1 ELSE 0 END) AS equipes_ativas,
    SUM(CASE WHEN eh_ativa = 0 THEN 1 ELSE 0 END) AS equipes_inativas
FROM dim.DIM_EQUIPE;
PRINT '';

-- 2. Distribuição por regional
PRINT '2. Equipes por Regional:';
SELECT 
    regional,
    COUNT(*) AS total_equipes,
    SUM(meta_mensal_equipe) AS meta_mensal_total,
    SUM(qtd_membros_atual) AS total_vendedores,
    AVG(meta_mensal_equipe) AS meta_media_equipe
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1
GROUP BY regional
ORDER BY meta_mensal_total DESC;
PRINT '';

-- 3. Distribuição por tipo
PRINT '3. Equipes por Tipo:';
SELECT 
    tipo_equipe,
    COUNT(*) AS total_equipes,
    AVG(meta_mensal_equipe) AS meta_media,
    SUM(qtd_membros_atual) AS total_membros
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND tipo_equipe IS NOT NULL
GROUP BY tipo_equipe
ORDER BY meta_media DESC;
PRINT '';

-- 4. Distribuição por categoria
PRINT '4. Equipes por Categoria de Performance:';
SELECT 
    categoria_equipe,
    COUNT(*) AS total_equipes,
    AVG(meta_mensal_equipe) AS meta_media,
    MIN(meta_mensal_equipe) AS meta_minima,
    MAX(meta_mensal_equipe) AS meta_maxima
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND categoria_equipe IS NOT NULL
GROUP BY categoria_equipe
ORDER BY meta_media DESC;
PRINT '';

-- 5. Top 5 equipes por meta
PRINT '5. Top 5 Equipes com Maiores Metas:';
SELECT TOP 5
    nome_equipe,
    tipo_equipe,
    regional,
    CAST(meta_mensal_equipe AS DECIMAL(15,2)) AS meta_mensal,
    qtd_membros_atual,
    CAST(meta_mensal_equipe / NULLIF(qtd_membros_atual, 0) AS DECIMAL(15,2)) AS meta_per_capita
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1
ORDER BY meta_mensal_equipe DESC;
PRINT '';

-- 6. Análise de capacidade (membros atual vs ideal)
PRINT '6. Análise de Capacidade das Equipes:';
SELECT 
    nome_equipe,
    qtd_membros_atual,
    qtd_membros_ideal,
    qtd_membros_ideal - qtd_membros_atual AS vagas_em_aberto,
    CAST((qtd_membros_atual * 100.0 / NULLIF(qtd_membros_ideal, 0)) AS DECIMAL(5,2)) AS percentual_capacidade
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND qtd_membros_ideal IS NOT NULL
ORDER BY vagas_em_aberto DESC;
PRINT '';

-- 7. Resumo por situação
PRINT '7. Equipes por Situação:';
SELECT 
    situacao,
    COUNT(*) AS total,
    SUM(qtd_membros_atual) AS total_vendedores
FROM dim.DIM_EQUIPE
GROUP BY situacao;
PRINT '';

-- 8. Listagem completa
PRINT '8. Amostra Geral das Equipes:';
SELECT 
    equipe_id,
    nome_equipe,
    codigo_equipe,
    tipo_equipe,
    regional,
    CAST(meta_mensal_equipe AS DECIMAL(15,2)) AS meta_mensal,
    qtd_membros_atual,
    situacao
FROM dim.DIM_EQUIPE
ORDER BY equipe_id;
PRINT '';

-- ========================================
-- 7. CRIAR VIEWS AUXILIARES
-- ========================================

PRINT '========================================';
PRINT 'CRIANDO VIEWS AUXILIARES';
PRINT '========================================';
PRINT '';

-- View 1: Equipes Ativas com Métricas
IF OBJECT_ID('dim.VW_EQUIPES_ATIVAS', 'V') IS NOT NULL
    DROP VIEW dim.VW_EQUIPES_ATIVAS;
GO

CREATE VIEW dim.VW_EQUIPES_ATIVAS
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_EQUIPES_ATIVAS                                               ║
║  Propósito: Facilitar queries mostrando apenas equipes operacionais   ║
║  Uso: SELECT * FROM dim.VW_EQUIPES_ATIVAS WHERE regional = 'Sul'      ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    equipe_id,
    equipe_original_id,
    nome_equipe,
    codigo_equipe,
    tipo_equipe,
    categoria_equipe,
    regional,
    estado_sede,
    cidade_sede,
    -- Metas
    meta_mensal_equipe,
    meta_trimestral_equipe,
    meta_anual_equipe,
    qtd_meta_vendas_mes,
    -- Composição
    qtd_membros_atual,
    qtd_membros_ideal,
    qtd_membros_ideal - qtd_membros_atual AS vagas_em_aberto,
    -- Meta per capita
    CASE 
        WHEN qtd_membros_atual > 0 
        THEN meta_mensal_equipe / qtd_membros_atual
        ELSE NULL 
    END AS meta_mensal_per_capita,
    -- Classificação de porte
    CASE 
        WHEN qtd_membros_atual >= 10 THEN 'Grande (10+)'
        WHEN qtd_membros_atual >= 5 THEN 'Média (5-9)'
        WHEN qtd_membros_atual >= 1 THEN 'Pequena (1-4)'
        ELSE 'Vazia (0)'
    END AS porte_equipe,
    -- Liderança
    lider_equipe_id,
    nome_lider,
    email_lider,
    -- Datas
    data_criacao,
    DATEDIFF(MONTH, data_criacao, GETDATE()) AS meses_ativa
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa';
GO

PRINT '✅ View dim.VW_EQUIPES_ATIVAS criada!';

-- View 2: Ranking de Equipes por Meta
IF OBJECT_ID('dim.VW_RANKING_EQUIPES_META', 'V') IS NOT NULL
    DROP VIEW dim.VW_RANKING_EQUIPES_META;
GO

CREATE VIEW dim.VW_RANKING_EQUIPES_META
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_RANKING_EQUIPES_META                                         ║
║  Propósito: Mostrar ranking das equipes por meta mensal               ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    ROW_NUMBER() OVER (ORDER BY meta_mensal_equipe DESC) AS ranking_geral,
    ROW_NUMBER() OVER (PARTITION BY regional ORDER BY meta_mensal_equipe DESC) AS ranking_regional,
    equipe_id,
    nome_equipe,
    tipo_equipe,
    regional,
    meta_mensal_equipe,
    qtd_membros_atual,
    CASE 
        WHEN qtd_membros_atual > 0 
        THEN meta_mensal_equipe / qtd_membros_atual
        ELSE NULL 
    END AS meta_per_capita,
    -- Classificação
    CASE 
        WHEN meta_mensal_equipe >= 500000 THEN 'Top (500k+)'
        WHEN meta_mensal_equipe >= 300000 THEN 'Alto (300k-500k)'
        WHEN meta_mensal_equipe >= 150000 THEN 'Médio (150k-300k)'
        ELSE 'Baixo (<150k)'
    END AS faixa_meta
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa';
GO

PRINT '✅ View dim.VW_RANKING_EQUIPES_META criada!';

-- View 3: Análise Regional
IF OBJECT_ID('dim.VW_ANALISE_REGIONAL_EQUIPES', 'V') IS NOT NULL
    DROP VIEW dim.VW_ANALISE_REGIONAL_EQUIPES;
GO

CREATE VIEW dim.VW_ANALISE_REGIONAL_EQUIPES
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_ANALISE_REGIONAL_EQUIPES                                     ║
║  Propósito: Agregação por regional para dashboards executivos         ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    regional,
    COUNT(*) AS total_equipes,
    SUM(qtd_membros_atual) AS total_vendedores,
    SUM(meta_mensal_equipe) AS meta_mensal_regional,
    AVG(meta_mensal_equipe) AS meta_media_por_equipe,
    MIN(meta_mensal_equipe) AS menor_meta,
    MAX(meta_mensal_equipe) AS maior_meta,
    -- Meta per capita regional
    SUM(meta_mensal_equipe) / NULLIF(SUM(qtd_membros_atual), 0) AS meta_per_capita_regional,
    -- Distribuição por tipo
    SUM(CASE WHEN tipo_equipe = 'Vendas Diretas' THEN 1 ELSE 0 END) AS equipes_diretas,
    SUM(CASE WHEN tipo_equipe = 'Inside Sales' THEN 1 ELSE 0 END) AS equipes_inside,
    SUM(CASE WHEN tipo_equipe = 'Key Accounts' THEN 1 ELSE 0 END) AS equipes_key_accounts,
    SUM(CASE WHEN tipo_equipe = 'E-commerce' THEN 1 ELSE 0 END) AS equipes_ecommerce
FROM dim.DIM_EQUIPE
WHERE eh_ativa = 1 AND situacao = 'Ativa'
GROUP BY regional;
GO

PRINT '✅ View dim.VW_ANALISE_REGIONAL_EQUIPES criada!';
PRINT '';

-- ========================================
-- 8. TESTE DAS VIEWS
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO VIEWS CRIADAS';
PRINT '========================================';
PRINT '';

PRINT '1. Equipes Ativas (sample):';
SELECT TOP 3 
    nome_equipe, 
    regional, 
    porte_equipe,
    CAST(meta_mensal_per_capita AS DECIMAL(15,2)) AS meta_per_capita
FROM dim.VW_EQUIPES_ATIVAS
ORDER BY meta_mensal_equipe DESC;
PRINT '';

PRINT '2. Ranking Geral (Top 5):';
SELECT TOP 5
    ranking_geral,
    nome_equipe,
    regional,
    faixa_meta,
    CAST(meta_mensal_equipe AS DECIMAL(15,2)) AS meta
FROM dim.VW_RANKING_EQUIPES_META;
PRINT '';

PRINT '3. Análise Regional:';
SELECT 
    regional,
    total_equipes,
    total_vendedores,
    CAST(meta_mensal_regional AS DECIMAL(15,2)) AS meta_total
FROM dim.VW_ANALISE_REGIONAL_EQUIPES
ORDER BY meta_mensal_regional DESC;
PRINT '';

-- ========================================
-- 9. ESTATÍSTICAS FINAIS
-- ========================================

PRINT '========================================';
PRINT 'ESTATÍSTICAS FINAIS';
PRINT '========================================';
PRINT '';

SELECT 
    '📊 RESUMO DA DIM_EQUIPE' AS titulo,
    (SELECT COUNT(*) FROM dim.DIM_EQUIPE) AS total_registros,
    (SELECT COUNT(*) FROM dim.DIM_EQUIPE WHERE eh_ativa = 1) AS equipes_ativas,
    (SELECT SUM(meta_mensal_equipe) FROM dim.DIM_EQUIPE WHERE eh_ativa = 1) AS meta_total_mensal,
    (SELECT SUM(qtd_membros_atual) FROM dim.DIM_EQUIPE WHERE eh_ativa = 1) AS total_vendedores_ativos,
    (SELECT COUNT(DISTINCT regional) FROM dim.DIM_EQUIPE WHERE regional IS NOT NULL) AS total_regionais;

PRINT '';
PRINT '✅✅✅ DIM_EQUIPE CRIADA E VALIDADA COM SUCESSO! ✅✅✅';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMOS PASSOS';
PRINT '========================================';
PRINT '';
PRINT '📌 Agora você pode:';
PRINT '   1. Criar DIM_VENDEDOR (com FK para DIM_EQUIPE)';
PRINT '   2. Atualizar FACT_VENDAS (adicionar vendedor_id)';
PRINT '   3. Criar FACT_METAS';
PRINT '';
PRINT '🔗 Relacionamentos a criar:';
PRINT '   • DIM_VENDEDOR.equipe_id → DIM_EQUIPE.equipe_id';
PRINT '   • DIM_EQUIPE.lider_equipe_id → DIM_VENDEDOR.vendedor_id';
PRINT '   • FACT_VENDAS.vendedor_id → DIM_VENDEDOR.vendedor_id';
PRINT '   • FACT_METAS.vendedor_id → DIM_VENDEDOR.vendedor_id';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO SCRIPT: 06_dim_vendedor.sql';
PRINT '========================================';
GO