-- ========================================
-- SCRIPT: 10_fact_descontos.sql
-- DESCRIÇÃO: Criação da FACT_DESCONTOS (ÚLTIMA TABELA!)
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2024-12-09
-- PRÉ-REQUISITOS: Todas dimensões + FACT_VENDAS criadas
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA FACT_DESCONTOS                                         ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta é a TABELA FATO que registra cada DESCONTO APLICADO.            ║
║  Diferente da DIM_DESCONTO (cadastro), esta armazena o USO efetivo.   ║
║                                                                        ║
║  📊 GRANULARIDADE:                                                     ║
║  • 1 linha = 1 DESCONTO APLICADO em 1 contexto                        ║
║                                                                        ║
║  🔗 RELACIONAMENTOS:                                                   ║
║  • FACT_DESCONTOS → DIM_DESCONTO (qual cupom?)                         ║
║  • FACT_DESCONTOS → FACT_VENDAS (em qual venda?)                       ║
║  • FACT_DESCONTOS → DIM_DATA (quando foi aplicado?)                    ║
║  • FACT_DESCONTOS → DIM_CLIENTE (quem usou?)                           ║
║  • FACT_DESCONTOS → DIM_PRODUTO (em qual produto?)                     ║
║                                                                        ║
║  📈 DIFERENÇA CHAVE:                                                   ║
║  • DIM_DESCONTO: "Cupom BLACKFRIDAY existe"                            ║
║  • FACT_DESCONTOS: "João usou BLACKFRIDAY na venda #123"              ║
║                                                                        ║
║  ✅ ANÁLISES POSSÍVEIS:                                                ║
║  • Quantas vezes cada cupom foi usado?                                 ║
║  • Qual cupom gerou mais receita?                                      ║
║  • ROI de campanhas                                                    ║
║  • Impacto na margem                                                   ║
║  • Produtos com mais desconto                                          ║
║  • Clientes que mais usam cupons                                       ║
║  • Análise temporal de descontos                                       ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA FACT_DESCONTOS - ÚLTIMA TABELA!';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. VERIFICAR PRÉ-REQUISITOS
-- ========================================

PRINT 'Verificando pré-requisitos...';
PRINT '';

DECLARE @erro BIT = 0;

IF OBJECT_ID('dim.DIM_DESCONTO', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_DESCONTO não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_DESCONTO existe';

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NULL
BEGIN
    PRINT '❌ FACT_VENDAS não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ FACT_VENDAS existe';

IF OBJECT_ID('dim.DIM_DATA', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_DATA não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_DATA existe';

IF OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_CLIENTE não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_CLIENTE existe';

IF OBJECT_ID('dim.DIM_PRODUTO', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_PRODUTO não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_PRODUTO existe';

IF @erro = 1
BEGIN
    PRINT '';
    PRINT '❌ Execute as tabelas faltantes antes de criar FACT_DESCONTOS!';
    RAISERROR('Pré-requisitos não atendidos', 16, 1);
    RETURN;
END

PRINT '';
PRINT '✅ Todos os pré-requisitos OK!';
PRINT '';

-- ========================================
-- 2. DROPAR TABELA SE EXISTIR
-- ========================================

IF OBJECT_ID('fact.FACT_DESCONTOS', 'U') IS NOT NULL
BEGIN
    DROP TABLE fact.FACT_DESCONTOS;
    PRINT '⚠️  Tabela fact.FACT_DESCONTOS existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 3. CRIAR TABELA FACT_DESCONTOS
-- ========================================

PRINT 'Criando tabela fact.FACT_DESCONTOS...';
PRINT '';

CREATE TABLE fact.FACT_DESCONTOS
(
    -- ============================================
    -- CHAVE PRIMÁRIA
    -- ============================================
    desconto_aplicado_id BIGINT IDENTITY(1,1) NOT NULL,
    -- PK única para cada aplicação de desconto
    
    -- ============================================
    -- CHAVES ESTRANGEIRAS (Dimensões)
    -- ============================================
    
    desconto_id INT NOT NULL,
    -- FK para DIM_DESCONTO
    -- Responde: "QUAL cupom foi usado?"
    
    venda_id BIGINT NOT NULL,
    -- FK para FACT_VENDAS
    -- Responde: "EM QUAL venda?"
    -- IMPORTANTE: Relacionamento FACT-to-FACT!
    
    data_aplicacao_id INT NOT NULL,
    -- FK para DIM_DATA
    -- Responde: "QUANDO foi aplicado?"
    -- Pode ser diferente da data da venda (aplicação prévia)
    
    cliente_id INT NOT NULL,
    -- FK para DIM_CLIENTE
    -- Responde: "QUEM usou?"
    -- Denormalizado de FACT_VENDAS para performance
    
    produto_id INT NULL,
    -- FK para DIM_PRODUTO
    -- Responde: "EM QUAL produto foi aplicado?"
    -- NULL = desconto no pedido total ou frete
    
    -- ============================================
    -- CONTEXTO DA APLICAÇÃO
    -- ============================================
    
    nivel_aplicacao VARCHAR(30) NOT NULL,
    -- Onde o desconto foi aplicado:
    --   'Item' - desconto em produto específico
    --   'Pedido' - desconto no carrinho total
    --   'Frete' - desconto no frete
    --   'Categoria' - desconto em categoria
    -- Importante para análise de efetividade
    
    -- ============================================
    -- MÉTRICAS FINANCEIRAS - VALORES
    -- ============================================
    -- Por que armazenar valores aqui?
    -- • Desconto pode ter sido calculado de forma específica
    -- • Permite análise precisa de impacto
    -- ============================================
    
    valor_desconto_aplicado DECIMAL(15,2) NOT NULL,
    -- Quanto de desconto foi EFETIVAMENTE dado
    -- Exemplo: R$ 300,00
    -- Sempre >= 0 (positivo representa desconto)
    
    valor_sem_desconto DECIMAL(15,2) NOT NULL,
    -- Valor original ANTES do desconto
    -- Exemplo: R$ 3.000,00
    
    valor_com_desconto DECIMAL(15,2) NOT NULL,
    -- Valor FINAL após aplicar o desconto
    -- Exemplo: R$ 2.700,00
    -- Cálculo: valor_sem_desconto - valor_desconto_aplicado
    
    -- ============================================
    -- MÉTRICAS DE IMPACTO
    -- ============================================
    -- Análise de como o desconto afetou a venda
    -- ============================================
    
    margem_antes_desconto DECIMAL(15,2) NULL,
    -- Margem que teria sem o desconto
    -- Cálculo: valor_sem_desconto - custo
    
    margem_apos_desconto DECIMAL(15,2) NULL,
    -- Margem real após o desconto
    -- Cálculo: valor_com_desconto - custo
    
    impacto_margem DECIMAL(15,2) NULL,
    -- Quanto o desconto reduziu a margem
    -- Cálculo: margem_antes - margem_apos
    -- Negativo = margem ficou negativa (prejuízo)
    
    percentual_desconto_efetivo DECIMAL(5,2) NOT NULL,
    -- % real de desconto aplicado
    -- Cálculo: (valor_desconto / valor_sem_desconto) * 100
    -- Pode ser diferente do % do cupom (ex: teto)
    
    -- ============================================
    -- CONTROLE E VALIDAÇÃO
    -- ============================================
    
    desconto_aprovado BIT NOT NULL DEFAULT 1,
    -- 0 = Aguardando aprovação
    -- 1 = Aprovado automaticamente ou por gestor
    -- Para descontos que exigem aprovação manual
    
    motivo_rejeicao VARCHAR(200) NULL,
    -- Se rejeitado, qual foi o motivo?
    -- NULL = aprovado
    
    -- ============================================
    -- DEGENERATE DIMENSION
    -- ============================================
    numero_pedido VARCHAR(20) NOT NULL,
    -- Número do pedido (mesmo da FACT_VENDAS)
    -- Facilita buscas por pedido completo
    
    -- ============================================
    -- AUDITORIA
    -- ============================================
    data_inclusao DATETIME NOT NULL DEFAULT GETDATE(),
    data_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- ============================================
    -- CONSTRAINTS
    -- ============================================
    
    CONSTRAINT PK_FACT_DESCONTOS 
        PRIMARY KEY CLUSTERED (desconto_aplicado_id),
    
    -- Foreign Keys
    CONSTRAINT FK_FACT_DESCONTOS_desconto 
        FOREIGN KEY (desconto_id) 
        REFERENCES dim.DIM_DESCONTO(desconto_id),
    
    CONSTRAINT FK_FACT_DESCONTOS_venda 
        FOREIGN KEY (venda_id) 
        REFERENCES fact.FACT_VENDAS(venda_id),
    
    CONSTRAINT FK_FACT_DESCONTOS_data 
        FOREIGN KEY (data_aplicacao_id) 
        REFERENCES dim.DIM_DATA(data_id),
    
    CONSTRAINT FK_FACT_DESCONTOS_cliente 
        FOREIGN KEY (cliente_id) 
        REFERENCES dim.DIM_CLIENTE(cliente_id),
    
    CONSTRAINT FK_FACT_DESCONTOS_produto 
        FOREIGN KEY (produto_id) 
        REFERENCES dim.DIM_PRODUTO(produto_id),
    
    -- Business Rules
    CONSTRAINT CK_FACT_DESCONTOS_valores_positivos 
        CHECK (
            valor_desconto_aplicado >= 0 AND
            valor_sem_desconto >= 0 AND
            valor_com_desconto >= 0
        ),
    
    CONSTRAINT CK_FACT_DESCONTOS_valor_coerente 
        CHECK (valor_com_desconto = valor_sem_desconto - valor_desconto_aplicado),
    
    CONSTRAINT CK_FACT_DESCONTOS_percentual_valido 
        CHECK (percentual_desconto_efetivo BETWEEN 0 AND 100),
    
    CONSTRAINT CK_FACT_DESCONTOS_nivel_valido 
        CHECK (nivel_aplicacao IN ('Item', 'Pedido', 'Frete', 'Categoria'))
);
GO

PRINT '✅ Tabela fact.FACT_DESCONTOS criada com sucesso!';
PRINT '';
PRINT '📊 Estrutura:';
PRINT '   • PK: desconto_aplicado_id (BIGINT)';
PRINT '   • 5 FKs: desconto, venda, data, cliente, produto';
PRINT '   • Métricas: valores, impacto na margem';
PRINT '   • Contexto: nível de aplicação';
PRINT '   • Controle: aprovação';
PRINT '';

-- ========================================
-- 4. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

-- Índice 1: Busca por desconto (análise de cupom)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_desconto
    ON fact.FACT_DESCONTOS(desconto_id)
    INCLUDE (venda_id, valor_desconto_aplicado, valor_com_desconto);
PRINT '  ✅ IX_FACT_DESCONTOS_desconto';
PRINT '     Uso: "Quantas vezes cupom X foi usado?"';

-- Índice 2: Busca por venda (descontos de um pedido)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_venda
    ON fact.FACT_DESCONTOS(venda_id)
    INCLUDE (desconto_id, valor_desconto_aplicado);
PRINT '  ✅ IX_FACT_DESCONTOS_venda';
PRINT '     Uso: "Quais descontos na venda #123?"';

-- Índice 3: Busca por data (análise temporal)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_data
    ON fact.FACT_DESCONTOS(data_aplicacao_id)
    INCLUDE (desconto_id, valor_desconto_aplicado);
PRINT '  ✅ IX_FACT_DESCONTOS_data';
PRINT '     Uso: "Descontos aplicados em Novembro"';

-- Índice 4: Busca por cliente (análise de comportamento)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_cliente
    ON fact.FACT_DESCONTOS(cliente_id)
    INCLUDE (desconto_id, valor_desconto_aplicado);
PRINT '  ✅ IX_FACT_DESCONTOS_cliente';
PRINT '     Uso: "Quais cupons o cliente X usou?"';

-- Índice 5: Busca por produto (produtos com mais desconto)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_produto
    ON fact.FACT_DESCONTOS(produto_id)
    INCLUDE (desconto_id, valor_desconto_aplicado)
    WHERE produto_id IS NOT NULL;
PRINT '  ✅ IX_FACT_DESCONTOS_produto';
PRINT '     Uso: "Descontos no produto Y"';

-- Índice 6: Combinado desconto + data (muito usado)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_desconto_data
    ON fact.FACT_DESCONTOS(desconto_id, data_aplicacao_id)
    INCLUDE (valor_desconto_aplicado);
PRINT '  ✅ IX_FACT_DESCONTOS_desconto_data';
PRINT '     Uso: "Uso do cupom ao longo do tempo"';

-- Índice 7: Número do pedido (lookup)
CREATE NONCLUSTERED INDEX IX_FACT_DESCONTOS_numero_pedido
    ON fact.FACT_DESCONTOS(numero_pedido)
    INCLUDE (desconto_id, valor_desconto_aplicado);
PRINT '  ✅ IX_FACT_DESCONTOS_numero_pedido';
PRINT '     Uso: "Descontos do pedido PED-123"';

PRINT '';

-- ========================================
-- 5. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO DESCONTOS APLICADOS DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar descontos aplicados baseados nas vendas existentes:
• Pegar vendas que tiveram desconto
• Aplicar cupons aleatórios
• Simular múltiplos descontos em alguns pedidos
*/

PRINT 'Gerando descontos aplicados...';

DECLARE @venda_loop BIGINT;
DECLARE @cliente_loop INT;
DECLARE @produto_loop INT;
DECLARE @data_loop INT;
DECLARE @valor_bruto DECIMAL(15,2);
DECLARE @valor_desconto DECIMAL(15,2);
DECLARE @valor_liquido DECIMAL(15,2);
DECLARE @numero_pedido_loop VARCHAR(20);
DECLARE @desconto_aleatorio INT;
DECLARE @custo_item DECIMAL(15,2);

-- Cursor para vendas com desconto
DECLARE vendas_cursor CURSOR FOR
SELECT 
    venda_id,
    cliente_id,
    produto_id,
    data_id,
    valor_total_bruto,
    valor_total_descontos,
    valor_total_liquido,
    numero_pedido,
    custo_total
FROM fact.FACT_VENDAS
WHERE teve_desconto = 1;

OPEN vendas_cursor;
FETCH NEXT FROM vendas_cursor INTO 
    @venda_loop, @cliente_loop, @produto_loop, @data_loop,
    @valor_bruto, @valor_desconto, @valor_liquido, @numero_pedido_loop, @custo_item;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Selecionar desconto aleatório ativo
    SELECT TOP 1 @desconto_aleatorio = desconto_id
    FROM dim.DIM_DESCONTO
    WHERE eh_ativo = 1
    ORDER BY NEWID();
    
    -- Inserir desconto aplicado
    INSERT INTO fact.FACT_DESCONTOS (
        desconto_id,
        venda_id,
        data_aplicacao_id,
        cliente_id,
        produto_id,
        nivel_aplicacao,
        valor_desconto_aplicado,
        valor_sem_desconto,
        valor_com_desconto,
        margem_antes_desconto,
        margem_apos_desconto,
        impacto_margem,
        percentual_desconto_efetivo,
        desconto_aprovado,
        numero_pedido
    )
    VALUES (
        @desconto_aleatorio,
        @venda_loop,
        @data_loop,
        @cliente_loop,
        @produto_loop,
        'Item',
        @valor_desconto,
        @valor_bruto,
        @valor_liquido,
        @valor_bruto - @custo_item, -- margem antes
        @valor_liquido - @custo_item, -- margem depois
        @valor_desconto, -- impacto
        (@valor_desconto / @valor_bruto) * 100, -- percentual
        1,
        @numero_pedido_loop
    );
    
    FETCH NEXT FROM vendas_cursor INTO 
        @venda_loop, @cliente_loop, @produto_loop, @data_loop,
        @valor_bruto, @valor_desconto, @valor_liquido, @numero_pedido_loop, @custo_item;
END

CLOSE vendas_cursor;
DEALLOCATE vendas_cursor;

PRINT '✅ Descontos aplicados inseridos!';
PRINT '';

-- ========================================
-- 6. ATUALIZAR DIM_DESCONTO COM TOTAIS
-- ========================================

PRINT 'Atualizando estatísticas na DIM_DESCONTO...';

UPDATE d
SET 
    total_usos_realizados = ISNULL(uso.total_usos, 0),
    total_receita_gerada = ISNULL(uso.total_receita, 0),
    total_desconto_concedido = ISNULL(uso.total_desconto, 0)
FROM dim.DIM_DESCONTO d
LEFT JOIN (
    SELECT 
        desconto_id,
        COUNT(*) AS total_usos,
        SUM(valor_com_desconto) AS total_receita,
        SUM(valor_desconto_aplicado) AS total_desconto
    FROM fact.FACT_DESCONTOS
    GROUP BY desconto_id
) AS uso ON d.desconto_id = uso.desconto_id;

PRINT '✅ Estatísticas atualizadas!';
PRINT '';

-- ========================================
-- 7. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Tabela Fato de Descontos - Registra cada aplicação de desconto/cupom. Granularidade: 1 desconto aplicado.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_DESCONTOS';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'FK para FACT_VENDAS - Relacionamento fact-to-fact. Em qual venda o desconto foi usado.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_DESCONTOS',
    @level2type = N'COLUMN', @level2name = 'venda_id';

PRINT '✅ Documentação adicionada!';
PRINT '';

-- ========================================
-- 8. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- 1. Total geral
PRINT '1. Resumo Geral:';
SELECT 
    COUNT(*) AS total_descontos_aplicados,
    COUNT(DISTINCT desconto_id) AS cupons_diferentes_usados,
    COUNT(DISTINCT venda_id) AS vendas_com_desconto,
    COUNT(DISTINCT cliente_id) AS clientes_usaram_cupom,
    SUM(valor_desconto_aplicado) AS total_desconto_concedido,
    SUM(valor_com_desconto) AS receita_com_desconto,
    AVG(percentual_desconto_efetivo) AS perc_medio_desconto
FROM fact.FACT_DESCONTOS;
PRINT '';

-- 2. Top 5 cupons mais usados
PRINT '2. Top 5 Cupons Mais Usados:';
SELECT TOP 5
    d.codigo_desconto,
    d.tipo_desconto,
    COUNT(*) AS total_usos,
    CAST(SUM(fd.valor_desconto_aplicado) AS DECIMAL(15,2)) AS total_desconto,
    CAST(SUM(fd.valor_com_desconto) AS DECIMAL(15,2)) AS receita_gerada
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.codigo_desconto, d.tipo_desconto
ORDER BY total_usos DESC;
PRINT '';

-- 3. Impacto na margem
PRINT '3. Análise de Impacto na Margem:';
SELECT 
    COUNT(*) AS total_descontos,
    CAST(AVG(margem_antes_desconto) AS DECIMAL(10,2)) AS margem_media_antes,
    CAST(AVG(margem_apos_desconto) AS DECIMAL(10,2)) AS margem_media_depois,
    CAST(AVG(impacto_margem) AS DECIMAL(10,2)) AS impacto_medio,
    SUM(CASE WHEN margem_apos_desconto < 0 THEN 1 ELSE 0 END) AS vendas_com_prejuizo
FROM fact.FACT_DESCONTOS;
PRINT '';

-- 4. Descontos por nível de aplicação
PRINT '4. Descontos por Nível de Aplicação:';
SELECT 
    nivel_aplicacao,
    COUNT(*) AS total,
    CAST(AVG(valor_desconto_aplicado) AS DECIMAL(10,2)) AS desconto_medio
FROM fact.FACT_DESCONTOS
GROUP BY nivel_aplicacao
ORDER BY total DESC;
PRINT '';

-- 5. Clientes que mais usam cupons
PRINT '5. Top 5 Clientes que Mais Usam Cupons:';
SELECT TOP 5
    c.nome_cliente,
    COUNT(*) AS total_cupons_usados,
    COUNT(DISTINCT fd.desconto_id) AS cupons_diferentes,
    CAST(SUM(fd.valor_desconto_aplicado) AS DECIMAL(10,2)) AS economia_total
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_CLIENTE c ON fd.cliente_id = c.cliente_id
GROUP BY c.nome_cliente
ORDER BY total_cupons_usados DESC;
PRINT '';

-- ========================================
-- 9. CRIAR VIEW ANALÍTICA
-- ========================================

PRINT '========================================';
PRINT 'CRIANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('fact.VW_DESCONTOS_COMPLETA', 'V') IS NOT NULL
    DROP VIEW fact.VW_DESCONTOS_COMPLETA;
GO

CREATE VIEW fact.VW_DESCONTOS_COMPLETA
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_DESCONTOS_COMPLETA                                           ║
║  Propósito: Análise completa de descontos aplicados                   ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    -- IDs
    fd.desconto_aplicado_id,
    fd.desconto_id,
    fd.venda_id,
    fd.numero_pedido,
    
    -- Desconto
    d.codigo_desconto,
    d.nome_campanha,
    d.tipo_desconto,
    d.metodo_desconto,
    d.origem_campanha,
    
    -- Data
    fd.data_aplicacao_id,
    dt.data_completa AS data_aplicacao,
    dt.ano,
    dt.mes,
    dt.nome_mes,
    
    -- Cliente
    fd.cliente_id,
    c.nome_cliente,
    c.tipo_cliente,
    c.segmento,
    
    -- Produto
    fd.produto_id,
    p.nome_produto,
    p.categoria,
    p.subcategoria,
    
    -- Contexto
    fd.nivel_aplicacao,
    
    -- Valores
    fd.valor_sem_desconto,
    fd.valor_desconto_aplicado,
    fd.valor_com_desconto,
    fd.percentual_desconto_efetivo,
    
    -- Impacto
    fd.margem_antes_desconto,
    fd.margem_apos_desconto,
    fd.impacto_margem,
    CASE 
        WHEN fd.margem_apos_desconto < 0 THEN 'Prejuízo'
        WHEN fd.margem_apos_desconto < fd.margem_antes_desconto * 0.3 THEN 'Margem Crítica'
        WHEN fd.margem_apos_desconto < fd.margem_antes_desconto * 0.6 THEN 'Margem Reduzida'
        ELSE 'Margem Saudável'
    END AS status_margem,
    
    -- Controle
    fd.desconto_aprovado,
    fd.motivo_rejeicao,
    
    -- ROI
    CASE 
        WHEN fd.valor_desconto_aplicado > 0 
        THEN (fd.valor_com_desconto - fd.valor_desconto_aplicado) / fd.valor_desconto_aplicado
        ELSE 0
    END AS roi_desconto

FROM fact.FACT_DESCONTOS fd
INNER JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
INNER JOIN dim.DIM_DATA dt ON fd.data_aplicacao_id = dt.data_id
INNER JOIN dim.DIM_CLIENTE c ON fd.cliente_id = c.cliente_id
LEFT JOIN dim.DIM_PRODUTO p ON fd.produto_id = p.produto_id;
GO

PRINT '✅ View fact.VW_DESCONTOS_COMPLETA criada!';
PRINT '';

-- ========================================
-- 10. TESTAR VIEW
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

PRINT '1. Sample de descontos:';
SELECT TOP 5
    codigo_desconto,
    nome_cliente,
    nome_produto,
    CAST(valor_desconto_aplicado AS DECIMAL(10,2)) AS desconto,
    CAST(percentual_desconto_efetivo AS DECIMAL(5,2)) AS perc,
    status_margem
FROM fact.VW_DESCONTOS_COMPLETA
ORDER BY valor_desc