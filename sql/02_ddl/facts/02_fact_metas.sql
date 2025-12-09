-- ========================================
-- SCRIPT: 08_fact_metas.sql
-- DESCRIÇÃO: Criação da FACT_METAS
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2024-12-08
-- PRÉ-REQUISITOS: DIM_VENDEDOR e DIM_DATA criadas
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA FACT_METAS                                             ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta é uma TABELA FATO PERIÓDICA (Periodic Snapshot).                ║
║  Armazena METAS e RESULTADOS de vendedores por período.               ║
║                                                                        ║
║  📊 GRANULARIDADE:                                                     ║
║  • 1 linha = META de 1 VENDEDOR em 1 MÊS                              ║
║                                                                        ║
║  🔗 RELACIONAMENTOS:                                                   ║
║  • FACT_METAS → DIM_VENDEDOR (de qual vendedor?)                       ║
║  • FACT_METAS → DIM_DATA (qual período?)                               ║
║  • FACT_METAS → DIM_EQUIPE (transitivo via DIM_VENDEDOR)              ║
║                                                                        ║
║  📈 DIFERENÇA DE FACT_VENDAS:                                          ║
║  • FACT_VENDAS: transacional (muitos registros/dia)                   ║
║  • FACT_METAS: periódica (1 registro/vendedor/mês)                    ║
║                                                                        ║
║  ✅ ANÁLISES POSSÍVEIS:                                                ║
║  • Vendedor atingiu meta?                                              ║
║  • % de atingimento ao longo do tempo                                  ║
║  • Comparação meta vs realizado                                        ║
║  • Ranking de performance                                              ║
║  • Tendências: melhorando ou piorando?                                 ║
║  • Previsões baseadas em histórico                                     ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA FACT_METAS';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. VERIFICAR PRÉ-REQUISITOS
-- ========================================

PRINT 'Verificando pré-requisitos...';
PRINT '';

DECLARE @erro BIT = 0;

IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_VENDEDOR não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_VENDEDOR existe';

IF OBJECT_ID('dim.DIM_DATA', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_DATA não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_DATA existe';

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
BEGIN
    PRINT '⚠️  FACT_VENDAS não existe (opcional, mas recomendado)';
END
ELSE PRINT '✅ FACT_VENDAS existe';

IF @erro = 1
BEGIN
    PRINT '';
    PRINT '❌ Execute as dimensões faltantes antes de criar FACT_METAS!';
    RAISERROR('Pré-requisitos não atendidos', 16, 1);
    RETURN;
END

PRINT '';
PRINT '✅ Todos os pré-requisitos OK!';
PRINT '';

-- ========================================
-- 2. DROPAR TABELA SE EXISTIR
-- ========================================

IF OBJECT_ID('fact.FACT_METAS', 'U') IS NOT NULL
BEGIN
    DROP TABLE fact.FACT_METAS;
    PRINT '⚠️  Tabela fact.FACT_METAS existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 3. CRIAR TABELA FACT_METAS
-- ========================================

PRINT 'Criando tabela fact.FACT_METAS...';
PRINT '';

CREATE TABLE fact.FACT_METAS
(
    -- ============================================
    -- CHAVE PRIMÁRIA
    -- ============================================
    meta_id BIGINT IDENTITY(1,1) NOT NULL,
    -- Por que BIGINT? 
    -- • Consistência com outras facts
    -- • Preparado para crescimento futuro
    
    -- ============================================
    -- CHAVES ESTRANGEIRAS (Dimensões)
    -- ============================================
    
    vendedor_id INT NOT NULL,
    -- FK para DIM_VENDEDOR
    -- Responde: "Meta de QUAL vendedor?"
    
    data_id INT NOT NULL,
    -- FK para DIM_DATA
    -- Responde: "Meta de QUAL período?"
    -- ATENÇÃO: Usar sempre o 1º dia do mês!
    -- Exemplo: Meta de Janeiro/2024 → data_id de 2024-01-01
    
    -- ============================================
    -- MÉTRICAS DE META (OBJETIVO)
    -- ============================================
    -- Por que separar valor e quantidade?
    -- • Vendedor pode ter meta em R$ E em nº de vendas
    -- • Exemplo: "Vender R$50k E fechar 20 negócios"
    -- ============================================
    
    valor_meta DECIMAL(15,2) NOT NULL,
    -- Meta de faturamento em R$ para o período
    -- Exemplo: R$ 50.000,00 por mês
    -- Sempre > 0
    
    quantidade_meta INT NULL,
    -- Meta de QUANTIDADE de vendas
    -- Exemplo: 20 vendas no mês
    -- NULL = sem meta de quantidade (só valor)
    
    -- ============================================
    -- MÉTRICAS REALIZADAS (O QUE ACONTECEU)
    -- ============================================
    -- Por que armazenar realizado aqui?
    -- • Snapshot: congela o que foi atingido
    -- • Performance: evita calcular sempre
    -- • Histórico: se FACT_VENDAS mudar, mantém registro
    -- ============================================
    
    valor_realizado DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Quanto o vendedor REALMENTE vendeu no período
    -- Calculado pela soma de FACT_VENDAS
    -- Exemplo: Vendeu R$ 52.500,00
    
    quantidade_realizada INT NOT NULL DEFAULT 0,
    -- QUANTAS vendas o vendedor fez
    -- Contagem de registros em FACT_VENDAS
    -- Exemplo: Fez 22 vendas
    
    -- ============================================
    -- MÉTRICAS CALCULADAS (PERFORMANCE)
    -- ============================================
    
    percentual_atingido DECIMAL(5,2) NOT NULL DEFAULT 0,
    -- % da meta alcançada
    -- Cálculo: (valor_realizado / valor_meta) * 100
    -- Exemplo: 105.00 = bateu 105% da meta
    -- Pode ser > 100 (superou meta)
    
    gap_meta DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Diferença entre realizado e meta
    -- Cálculo: valor_realizado - valor_meta
    -- Positivo = superou, Negativo = não atingiu
    -- Exemplo: +R$2.500 (vendeu R$2.5k a mais)
    
    -- ============================================
    -- MÉTRICAS DE TICKET MÉDIO
    -- ============================================
    
    ticket_medio_realizado DECIMAL(10,2) NULL,
    -- Ticket médio das vendas do período
    -- Cálculo: valor_realizado / quantidade_realizada
    -- NULL = sem vendas no período
    
    -- ============================================
    -- CLASSIFICAÇÃO E RANKING
    -- ============================================
    
    ranking_periodo INT NULL,
    -- Posição do vendedor no ranking do mês
    -- 1 = melhor vendedor
    -- Calculado após fechar o período
    
    quartil_performance VARCHAR(10) NULL,
    -- Classificação por quartil
    -- 'Q1' = Top 25% (melhores)
    -- 'Q2' = 25-50%
    -- 'Q3' = 50-75%
    -- 'Q4' = Bottom 25%
    
    -- ============================================
    -- FLAGS (Indicadores Booleanos)
    -- ============================================
    
    meta_batida BIT NOT NULL DEFAULT 0,
    -- 0 = Não atingiu meta
    -- 1 = Atingiu ou superou meta
    -- Facilita queries: "Quantos bateram meta?"
    
    meta_superada BIT NOT NULL DEFAULT 0,
    -- 0 = Não superou (mesmo que tenha batido exato)
    -- 1 = Superou (> 100%)
    
    eh_periodo_fechado BIT NOT NULL DEFAULT 0,
    -- 0 = Período ainda em andamento
    -- 1 = Período encerrado (dados congelados)
    -- Útil para saber se dados são finais ou parciais
    
    -- ============================================
    -- OBSERVAÇÕES E CONTEXTO
    -- ============================================
    
    tipo_periodo VARCHAR(20) NOT NULL DEFAULT 'Mensal',
    -- Tipo do período da meta
    -- 'Mensal', 'Trimestral', 'Anual'
    -- Permite metas de diferentes granularidades
    
    observacoes VARCHAR(500) NULL,
    -- Notas sobre a meta
    -- Exemplo: "Meta ajustada devido a férias"
    
    -- ============================================
    -- AUDITORIA
    -- ============================================
    
    data_inclusao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Quando foi criado este registro
    
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Última vez que valor_realizado foi atualizado
    -- Atualizado diariamente pelo ETL
    
    -- ============================================
    -- CONSTRAINTS
    -- ============================================
    
    CONSTRAINT PK_FACT_METAS 
        PRIMARY KEY CLUSTERED (meta_id),
    
    -- Unique: Não pode ter 2 metas do mesmo vendedor no mesmo período
    CONSTRAINT UK_FACT_METAS_vendedor_periodo 
        UNIQUE (vendedor_id, data_id, tipo_periodo),
    
    -- Foreign Keys
    CONSTRAINT FK_FACT_METAS_vendedor 
        FOREIGN KEY (vendedor_id) 
        REFERENCES dim.DIM_VENDEDOR(vendedor_id),
    
    CONSTRAINT FK_FACT_METAS_data 
        FOREIGN KEY (data_id) 
        REFERENCES dim.DIM_DATA(data_id),
    
    -- Business Rules
    CONSTRAINT CK_FACT_METAS_valor_meta_positivo 
        CHECK (valor_meta > 0),
    
    CONSTRAINT CK_FACT_METAS_valores_positivos 
        CHECK (valor_realizado >= 0 AND quantidade_realizada >= 0),
    
    CONSTRAINT CK_FACT_METAS_percentual_valido 
        CHECK (percentual_atingido >= 0),
    
    CONSTRAINT CK_FACT_METAS_tipo_periodo 
        CHECK (tipo_periodo IN ('Mensal', 'Trimestral', 'Anual')),
    
    CONSTRAINT CK_FACT_METAS_quartil 
        CHECK (quartil_performance IN ('Q1', 'Q2', 'Q3', 'Q4') OR quartil_performance IS NULL),
    
    -- Lógica: se bateu meta, percentual >= 100
    CONSTRAINT CK_FACT_METAS_meta_batida_coerente 
        CHECK (
            (meta_batida = 0 AND percentual_atingido < 100) OR
            (meta_batida = 1 AND percentual_atingido >= 100)
        )
);
GO

PRINT '✅ Tabela fact.FACT_METAS criada com sucesso!';
PRINT '';
PRINT '📊 Estrutura:';
PRINT '   • PK: meta_id (BIGINT)';
PRINT '   • 2 FKs: vendedor, data';
PRINT '   • Granularidade: 1 meta por vendedor por período';
PRINT '   • Tipo: Periodic Snapshot Fact';
PRINT '';

-- ========================================
-- 4. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

-- Índice 1: Busca por vendedor (muito usado)
CREATE NONCLUSTERED INDEX IX_FACT_METAS_vendedor
    ON fact.FACT_METAS(vendedor_id)
    INCLUDE (data_id, valor_meta, valor_realizado, percentual_atingido);
PRINT '  ✅ IX_FACT_METAS_vendedor';
PRINT '     Uso: "Histórico de metas do vendedor X"';

-- Índice 2: Busca por período
CREATE NONCLUSTERED INDEX IX_FACT_METAS_data
    ON fact.FACT_METAS(data_id)
    INCLUDE (vendedor_id, valor_realizado, meta_batida);
PRINT '  ✅ IX_FACT_METAS_data';
PRINT '     Uso: "Metas de Dezembro/2024"';

-- Índice 3: Combinado vendedor + data (lookup comum)
CREATE NONCLUSTERED INDEX IX_FACT_METAS_vendedor_data
    ON fact.FACT_METAS(vendedor_id, data_id)
    INCLUDE (valor_meta, valor_realizado, percentual_atingido);
PRINT '  ✅ IX_FACT_METAS_vendedor_data';
PRINT '     Uso: "Meta do vendedor X em Janeiro"';

-- Índice 4: Filtro por meta batida
CREATE NONCLUSTERED INDEX IX_FACT_METAS_meta_batida
    ON fact.FACT_METAS(meta_batida, data_id)
    INCLUDE (vendedor_id, percentual_atingido)
    WHERE meta_batida = 1;
PRINT '  ✅ IX_FACT_METAS_meta_batida';
PRINT '     Uso: "Quantos bateram meta em 2024?"';

-- Índice 5: Ordenação por ranking
CREATE NONCLUSTERED INDEX IX_FACT_METAS_ranking
    ON fact.FACT_METAS(data_id, ranking_periodo)
    INCLUDE (vendedor_id, valor_realizado)
    WHERE ranking_periodo IS NOT NULL;
PRINT '  ✅ IX_FACT_METAS_ranking';
PRINT '     Uso: "Top 10 vendedores do mês"';

PRINT '';

-- ========================================
-- 5. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO METAS DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar metas para os últimos 6 meses:
• Todos os vendedores ativos
• Metas realistas baseadas em DIM_VENDEDOR.meta_mensal_base
• Valores realizados aleatórios (80%-120% da meta)
*/

PRINT 'Gerando metas dos últimos 6 meses...';

DECLARE @mes_atual DATE = DATEFIRST(DATEADD(MONTH, -5, GETDATE())); -- 6 meses atrás
DECLARE @mes_fim DATE = DATEFIRST(GETDATE());
DECLARE @mes_loop DATE;
DECLARE @vendedor_loop INT;
DECLARE @meta_base DECIMAL(15,2);
DECLARE @realizado DECIMAL(15,2);
DECLARE @qtd_meta INT;
DECLARE @qtd_realizada INT;
DECLARE @data_id_meta INT;

-- Loop pelos últimos 6 meses
SET @mes_loop = @mes_atual;

WHILE @mes_loop <= @mes_fim
BEGIN
    PRINT 'Processando mês: ' + CONVERT(VARCHAR, @mes_loop, 23);
    
    -- Buscar data_id do 1º dia do mês
    SELECT @data_id_meta = data_id 
    FROM dim.DIM_DATA 
    WHERE data_completa = @mes_loop;
    
    -- Para cada vendedor ativo
    DECLARE vendedor_cursor CURSOR FOR
    SELECT vendedor_id, meta_mensal_base
    FROM dim.DIM_VENDEDOR
    WHERE eh_ativo = 1 AND meta_mensal_base IS NOT NULL;
    
    OPEN vendedor_cursor;
    FETCH NEXT FROM vendedor_cursor INTO @vendedor_loop, @meta_base;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Meta de quantidade (estimativa: 1 venda a cada R$2.500)
        SET @qtd_meta = CAST(@meta_base / 2500 AS INT);
        
        -- Valor realizado: entre 70% e 130% da meta (aleatório)
        SET @realizado = @meta_base * (0.7 + (RAND() * 0.6));
        
        -- Quantidade realizada proporcional
        SET @qtd_realizada = CAST((@realizado / @meta_base) * @qtd_meta AS INT);
        
        -- Inserir meta
        INSERT INTO fact.FACT_METAS (
            vendedor_id,
            data_id,
            valor_meta,
            quantidade_meta,
            valor_realizado,
            quantidade_realizada,
            percentual_atingido,
            gap_meta,
            ticket_medio_realizado,
            meta_batida,
            meta_superada,
            eh_periodo_fechado,
            tipo_periodo
        )
        VALUES (
            @vendedor_loop,
            @data_id_meta,
            @meta_base,
            @qtd_meta,
            @realizado,
            @qtd_realizada,
            (@realizado / @meta_base) * 100, -- percentual
            @realizado - @meta_base, -- gap
            CASE WHEN @qtd_realizada > 0 THEN @realizado / @qtd_realizada ELSE NULL END, -- ticket médio
            CASE WHEN @realizado >= @meta_base THEN 1 ELSE 0 END, -- bateu meta
            CASE WHEN @realizado > @meta_base THEN 1 ELSE 0 END, -- superou meta
            CASE WHEN @mes_loop < DATEFIRST(GETDATE()) THEN 1 ELSE 0 END, -- período fechado
            'Mensal'
        );
        
        FETCH NEXT FROM vendedor_cursor INTO @vendedor_loop, @meta_base;
    END
    
    CLOSE vendedor_cursor;
    DEALLOCATE vendedor_cursor;
    
    -- Próximo mês
    SET @mes_loop = DATEADD(MONTH, 1, @mes_loop);
END

PRINT '✅ Metas inseridas!';
PRINT '';

-- Calcular rankings para cada período
PRINT 'Calculando rankings...';

UPDATE fm
SET ranking_periodo = ranking
FROM fact.FACT_METAS fm
INNER JOIN (
    SELECT 
        meta_id,
        ROW_NUMBER() OVER (PARTITION BY data_id ORDER BY valor_realizado DESC) AS ranking
    FROM fact.FACT_METAS
) AS ranked ON fm.meta_id = ranked.meta_id;

PRINT '✅ Rankings calculados!';
PRINT '';

-- Calcular quartis
PRINT 'Calculando quartis...';

UPDATE fm
SET quartil_performance = quartil
FROM fact.FACT_METAS fm
INNER JOIN (
    SELECT 
        meta_id,
        CASE 
            WHEN NTILE(4) OVER (PARTITION BY data_id ORDER BY percentual_atingido DESC) = 1 THEN 'Q1'
            WHEN NTILE(4) OVER (PARTITION BY data_id ORDER BY percentual_atingido DESC) = 2 THEN 'Q2'
            WHEN NTILE(4) OVER (PARTITION BY data_id ORDER BY percentual_atingido DESC) = 3 THEN 'Q3'
            ELSE 'Q4'
        END AS quartil
    FROM fact.FACT_METAS
) AS quartis ON fm.meta_id = quartis.meta_id;

PRINT '✅ Quartis calculados!';
PRINT '';

-- ========================================
-- 6. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Tabela Fato de Metas - Periodic Snapshot. Armazena metas e resultados de vendedores por período.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_METAS';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Percentual da meta atingido. Calculado como (valor_realizado/valor_meta)*100. Pode ser >100.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_METAS',
    @level2type = N'COLUMN', @level2name = 'percentual_atingido';

PRINT '✅ Documentação adicionada!';
PRINT '';

-- ========================================
-- 7. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- 1. Total geral
PRINT '1. Resumo Geral:';
SELECT 
    COUNT(*) AS total_metas,
    COUNT(DISTINCT vendedor_id) AS vendedores_com_meta,
    COUNT(DISTINCT data_id) AS periodos_cadastrados,
    SUM(CASE WHEN meta_batida = 1 THEN 1 ELSE 0 END) AS metas_atingidas,
    CAST(AVG(percentual_atingido) AS DECIMAL(5,2)) AS percentual_medio
FROM fact.FACT_METAS;
PRINT '';

-- 2. Performance por mês
PRINT '2. Performance por Mês:';
SELECT TOP 6
    d.ano,
    d.mes,
    d.nome_mes,
    COUNT(*) AS total_vendedores,
    SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) AS bateram_meta,
    CAST(AVG(fm.percentual_atingido) AS DECIMAL(5,2)) AS perc_medio,
    CAST(SUM(fm.valor_realizado) AS DECIMAL(15,2)) AS faturamento_total
FROM fact.FACT_METAS fm
JOIN dim.DIM_DATA d ON fm.data_id = d.data_id
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.ano DESC, d.mes DESC;
PRINT '';

-- 3. Top 10 vendedores (acumulado)
PRINT '3. Top 10 Vendedores (performance acumulada):';
SELECT TOP 10
    v.nome_vendedor,
    v.cargo,
    COUNT(*) AS total_meses,
    SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) AS meses_bateu_meta,
    CAST(AVG(fm.percentual_atingido) AS DECIMAL(5,2)) AS perc_medio,
    CAST(SUM(fm.valor_realizado) AS DECIMAL(15,2)) AS total_vendido
FROM fact.FACT_METAS fm
JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
GROUP BY v.nome_vendedor, v.cargo
ORDER BY perc_medio DESC;
PRINT '';

-- 4. Distribuição por quartil
PRINT '4. Distribuição por Quartil:';
SELECT 
    quartil_performance,
    COUNT(*) AS total,
    CAST(AVG(percentual_atingido) AS DECIMAL(5,2)) AS perc_medio,
    MIN(percentual_atingido) AS perc_minimo,
    MAX(percentual_atingido) AS perc_maximo
FROM fact.FACT_METAS
WHERE quartil_performance IS NOT NULL
GROUP BY quartil_performance
ORDER BY quartil_performance;
PRINT '';

-- 5. Análise de consistência
PRINT '5. Vendedores Consistentes (sempre batem meta):';
SELECT 
    v.nome_vendedor,
    COUNT(*) AS total_periodos,
    SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) AS periodos_bateu,
    CAST(SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS taxa_sucesso
FROM fact.FACT_METAS fm
JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
GROUP BY v.nome_vendedor
HAVING SUM(CASE WHEN fm.meta_batida = 1 THEN 1 ELSE 0 END) = COUNT(*)
ORDER BY taxa_sucesso DESC;
PRINT '';

-- ========================================
-- 8. CRIAR VIEW ANALÍTICA
-- ========================================

PRINT '========================================';
PRINT 'CRIANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('fact.VW_METAS_COMPLETA', 'V') IS NOT NULL
    DROP VIEW fact.VW_METAS_COMPLETA;
GO

CREATE VIEW fact.VW_METAS_COMPLETA
AS
SELECT 
    -- IDs
    fm.meta_id,
    fm.vendedor_id,
    fm.data_id,
    
    -- Período
    d.data_completa AS data_periodo,
    d.ano,
    d.trimestre,
    d.mes,
    d.nome_mes,
    fm.tipo_periodo,
    fm.eh_periodo_fechado,
    
    -- Vendedor
    v.nome_vendedor,
    v.nome_exibicao AS apelido_vendedor,
    v.cargo,
    v.nivel_senioridade,
    
    -- Equipe
    v.equipe_id,
    e.nome_equipe,
    e.tipo_equipe,
    e.regional,
    
    -- Metas
    fm.valor_meta,
    fm.quantidade_meta,
    fm.valor_realizado,
    fm.quantidade_realizada,
    
    -- Performance
    fm.percentual_atingido,
    fm.gap_meta,
    fm.ticket_medio_realizado,
    fm.ranking_periodo,
    fm.quartil_performance,
    
    -- Flags
    fm.meta_batida,
    fm.meta_superada,
    
    -- Classificações
    CASE 
        WHEN fm.percentual_atingido >= 120 THEN 'Excepcional (120%+)'
        WHEN fm.percentual_atingido >= 100 THEN 'Atingiu (100-120%)'
        WHEN fm.percentual_atingido >= 80 THEN 'Próximo (80-100%)'
        WHEN fm.percentual_atingido >= 50 THEN 'Abaixo (50-80%)'
        ELSE 'Crítico (<50%)'
    END AS faixa_performance,
    
    -- Auditoria
    fm.data_inclusao,
    fm.data_ultima_atualizacao

FROM fact.FACT_METAS fm
INNER JOIN dim.DIM_DATA d ON fm.data_id = d.data_id
INNER JOIN dim.DIM_VENDEDOR v ON fm.vendedor_id = v.vendedor_id
LEFT JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id;
GO

PRINT '✅ View fact.VW_METAS_COMPLETA criada!';
PRINT '';

-- ========================================
-- 9. TESTAR VIEW
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

PRINT '1. Sample de metas:';
SELECT TOP 5
    nome_vendedor,
    nome_mes + '/' + CAST(ano AS VARCHAR) AS periodo,
    CAST(valor_meta AS DECIMAL(10,2)) AS meta,
    CAST(valor_realizado AS DECIMAL(10,2