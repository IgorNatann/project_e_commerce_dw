-- ========================================
-- SCRIPT: 01_fact_vendas.sql
-- DESCRIÇÃO: Criação da FACT_VENDAS (Tabela Fato Principal)
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2025-12-08
-- PRÉ-REQUISITOS: Todas as dimensões criadas
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA FACT_VENDAS                                            ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta é a TABELA FATO PRINCIPAL do Data Warehouse.                    ║
║  Armazena cada TRANSAÇÃO DE VENDA no menor nível de detalhe.          ║
║                                                                        ║
║  📊 GRANULARIDADE:                                                     ║
║  • 1 linha = 1 ITEM vendido em 1 pedido                               ║
║                                                                        ║
║  🔗 RELACIONAMENTOS (Star Schema):                                     ║
║  • FACT_VENDAS → DIM_DATA (quando foi?)                               ║
║  • FACT_VENDAS → DIM_CLIENTE (quem comprou?)                           ║
║  • FACT_VENDAS → DIM_PRODUTO (o que comprou?)                          ║
║  • FACT_VENDAS → DIM_REGIAO (onde foi entregue?)                       ║
║  • FACT_VENDAS → DIM_VENDEDOR (quem vendeu?)                           ║
║                                                                        ║
║  📈 MÉTRICAS ARMAZENADAS:                                              ║
║  • Quantidade vendida                                                  ║
║  • Valores (bruto, descontos, líquido)                                 ║
║  • Custos                                                              ║
║  • Devoluções                                                          ║
║  • Comissões                                                           ║
║                                                                        ║
║  ✅ ANÁLISES POSSÍVEIS:                                                ║
║  • Vendas por período (dia/mês/ano)                                    ║
║  • Vendas por região/estado                                            ║
║  • Vendas por categoria de produto                                     ║
║  • Performance de vendedores                                           ║
║  • Ticket médio por cliente                                            ║
║  • Taxa de devolução                                                   ║
║  • Margem de lucro                                                     ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA FACT_VENDAS';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. VERIFICAR PRÉ-REQUISITOS
-- ========================================

PRINT 'Verificando pré-requisitos...';
PRINT '';

DECLARE @erro BIT = 0;

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

IF OBJECT_ID('dim.DIM_REGIAO', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_REGIAO não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_REGIAO existe';

IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NULL
BEGIN
    PRINT '❌ DIM_VENDEDOR não existe!';
    SET @erro = 1;
END
ELSE PRINT '✅ DIM_VENDEDOR existe';

IF @erro = 1
BEGIN
    PRINT '';
    PRINT '❌ Execute as dimensões faltantes antes de criar a FACT!';
    RAISERROR('Pré-requisitos não atendidos', 16, 1);
    RETURN;
END

PRINT '';
PRINT '✅ Todos os pré-requisitos OK!';
PRINT '';

-- ========================================
-- 2. DROPAR TABELA SE EXISTIR
-- ========================================

IF OBJECT_ID('fact.FACT_VENDAS', 'U') IS NOT NULL
BEGIN
    DROP TABLE fact.FACT_VENDAS;
    PRINT '⚠️  Tabela fact.FACT_VENDAS existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 3. CRIAR TABELA FACT_VENDAS
-- ========================================

PRINT 'Criando tabela fact.FACT_VENDAS...';
PRINT '';

CREATE TABLE fact.FACT_VENDAS
(
    -- ============================================
    -- CHAVE PRIMÁRIA (Surrogate Key da Fact)
    -- ============================================
    venda_id BIGINT IDENTITY(1,1) NOT NULL,
    -- Por que BIGINT? Facts crescem MUITO!
    -- Um INT suporta até ~2 bilhões de registros
    -- BIGINT suporta até 9 quintilhões
    
    -- ============================================
    -- CHAVES ESTRANGEIRAS (Foreign Keys)
    -- ============================================
    -- Por que todas essas FKs?
    -- • Conectam a fact com as dimensões (Star Schema)
    -- • Permitem análise: "vendas por região", "vendas por mês", etc
    -- • São o coração do modelo dimensional!
    -- ============================================
    
    data_id INT NOT NULL,
    -- FK para DIM_DATA
    -- Responde: "QUANDO foi a venda?"
    
    cliente_id INT NOT NULL,
    -- FK para DIM_CLIENTE
    -- Responde: "QUEM comprou?"
    
    produto_id INT NOT NULL,
    -- FK para DIM_PRODUTO
    -- Responde: "O QUE foi vendido?"
    
    regiao_id INT NOT NULL,
    -- FK para DIM_REGIAO
    -- Responde: "ONDE foi entregue?"
    
    vendedor_id INT NULL,
    -- FK para DIM_VENDEDOR
    -- Responde: "QUEM vendeu?"
    -- NULL = venda sem vendedor (e-commerce direto, self-service)
    
    -- ============================================
    -- MÉTRICAS DE QUANTIDADE
    -- ============================================
    quantidade_vendida INT NOT NULL,
    -- Quantas unidades deste produto foram vendidas
    -- Exemplo: 2 notebooks, 5 mouses
    -- Por que INT? Raramente vendemos frações
    
    -- ============================================
    -- MÉTRICAS FINANCEIRAS - VALORES
    -- ============================================
    -- Por que separar bruto/descontos/líquido?
    -- • Análise de impacto de descontos
    -- • Cálculo de margem real
    -- • Transparência para auditoria
    -- ============================================
    
    preco_unitario_tabela DECIMAL(10,2) NOT NULL,
    -- Preço de tabela (SEM desconto) por unidade
    -- Exemplo: R$ 3.500,00 por notebook
    
    valor_total_bruto DECIMAL(15,2) NOT NULL,
    -- Valor ANTES de descontos
    -- Cálculo: quantidade * preco_unitario_tabela
    -- Exemplo: 2 notebooks * R$ 3.500 = R$ 7.000,00
    
    valor_total_descontos DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Total de descontos aplicados neste item
    -- Exemplo: -R$ 700,00 (10% de desconto)
    -- Sempre >= 0 (positivo representa desconto)
    
    valor_total_liquido DECIMAL(15,2) NOT NULL,
    -- Valor FINAL pago pelo cliente
    -- Cálculo: valor_total_bruto - valor_total_descontos
    -- Exemplo: R$ 7.000 - R$ 700 = R$ 6.300,00
    -- Esta é a RECEITA REAL!
    
    -- ============================================
    -- MÉTRICAS FINANCEIRAS - CUSTOS
    -- ============================================
    custo_total DECIMAL(15,2) NOT NULL,
    -- Quanto custou para nós esse produto
    -- Cálculo: quantidade * custo_unitario (vem da DIM_PRODUTO)
    -- Exemplo: 2 notebooks * R$ 2.000 = R$ 4.000,00
    -- Usado para calcular MARGEM
    
    -- ============================================
    -- MÉTRICAS DE DEVOLUÇÃO
    -- ============================================
    -- Por que armazenar devoluções aqui?
    -- • Mantém histórico completo da transação
    -- • Facilita análise: "qual produto tem mais devolução?"
    -- • Alternativa seria criar FACT_DEVOLUCOES separada
    -- ============================================
    
    quantidade_devolvida INT NOT NULL DEFAULT 0,
    -- Quantas unidades foram devolvidas
    -- Exemplo: Cliente devolveu 1 dos 2 notebooks
    -- Sempre <= quantidade_vendida
    
    valor_devolvido DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Valor que foi REEMBOLSADO ao cliente
    -- Pode ser diferente do valor_total_liquido se devolução parcial
    -- Exemplo: Devolveu 1 notebook = R$ 3.150,00
    
    -- ============================================
    -- MÉTRICAS DE COMISSÃO
    -- ============================================
    percentual_comissao DECIMAL(5,2) NULL,
    -- % de comissão do vendedor nesta venda
    -- Exemplo: 3.50 = 3.5%
    -- Pode variar por produto/campanha
    -- NULL = venda sem comissão
    
    valor_comissao DECIMAL(15,2) NULL,
    -- Valor em R$ da comissão
    -- Cálculo: valor_total_liquido * (percentual_comissao / 100)
    -- Exemplo: R$ 6.300 * 3.5% = R$ 220,50
    
    -- ============================================
    -- DEGENERATE DIMENSION
    -- ============================================
    -- O que é Degenerate Dimension?
    -- • Atributo descritivo que fica na FACT
    -- • Não justifica criar dimensão separada
    -- • Exemplo clássico: número do pedido
    -- ============================================
    
    numero_pedido VARCHAR(20) NOT NULL,
    -- Número do pedido original
    -- Exemplo: "PED-2024-123456"
    -- Por que não criar DIM_PEDIDO?
    -- • Seria 1:N com fact (sem agregação)
    -- • Não tem atributos descritivos relevantes
    -- • Degenerate dimension é suficiente
    
    -- ============================================
    -- FLAGS (Atributos Booleanos)
    -- ============================================
    teve_desconto BIT NOT NULL DEFAULT 0,
    -- 0 = Sem desconto, 1 = Com desconto
    -- Facilita filtros: "vendas com desconto"
    -- Pode ser calculado (valor_total_descontos > 0)
    -- mas armazenar melhora performance
    
    -- ============================================
    -- AUDITORIA E CONTROLE
    -- ============================================
    data_inclusao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Quando este registro foi inserido no DW
    -- Útil para rastrear processo ETL
    
    data_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Última atualização (devoluções, correções)
    
    -- ============================================
    -- CONSTRAINTS (Regras de Integridade)
    -- ============================================
    
    CONSTRAINT PK_FACT_VENDAS 
        PRIMARY KEY CLUSTERED (venda_id),
    
    -- Foreign Keys
    CONSTRAINT FK_FACT_VENDAS_data 
        FOREIGN KEY (data_id) 
        REFERENCES dim.DIM_DATA(data_id),
    
    CONSTRAINT FK_FACT_VENDAS_cliente 
        FOREIGN KEY (cliente_id) 
        REFERENCES dim.DIM_CLIENTE(cliente_id),
    
    CONSTRAINT FK_FACT_VENDAS_produto 
        FOREIGN KEY (produto_id) 
        REFERENCES dim.DIM_PRODUTO(produto_id),
    
    CONSTRAINT FK_FACT_VENDAS_regiao 
        FOREIGN KEY (regiao_id) 
        REFERENCES dim.DIM_REGIAO(regiao_id),
    
    CONSTRAINT FK_FACT_VENDAS_vendedor 
        FOREIGN KEY (vendedor_id) 
        REFERENCES dim.DIM_VENDEDOR(vendedor_id),
    
    -- Business Rules
    CONSTRAINT CK_FACT_VENDAS_quantidade_positiva 
        CHECK (quantidade_vendida > 0),
    
    CONSTRAINT CK_FACT_VENDAS_valores_positivos 
        CHECK (
            valor_total_bruto >= 0 AND
            valor_total_descontos >= 0 AND
            valor_total_liquido >= 0 AND
            custo_total >= 0
        ),
    
    CONSTRAINT CK_FACT_VENDAS_devolucao_valida 
        CHECK (quantidade_devolvida >= 0 AND quantidade_devolvida <= quantidade_vendida),
    
    CONSTRAINT CK_FACT_VENDAS_valor_liquido_coerente 
        CHECK (valor_total_liquido = valor_total_bruto - valor_total_descontos),
    
    CONSTRAINT CK_FACT_VENDAS_comissao_valida 
        CHECK (percentual_comissao IS NULL OR percentual_comissao BETWEEN 0 AND 100)
);
GO

PRINT '✅ Tabela fact.FACT_VENDAS criada com sucesso!';
PRINT '';
PRINT '📊 Estrutura:';
PRINT '   • PK: venda_id (BIGINT - suporta bilhões)';
PRINT '   • 5 FKs: data, cliente, produto, região, vendedor';
PRINT '   • Métricas: quantidades, valores, custos, devoluções, comissões';
PRINT '   • Degenerate Dimension: numero_pedido';
PRINT '   • Flags: teve_desconto';
PRINT '';

-- ========================================
-- 4. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

/*
╔════════════════════════════════════════════════════════════════════════╗
║  📚 ESTRATÉGIA DE INDEXAÇÃO PARA FACTS                                 ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Facts são ENORMES! Índices são CRÍTICOS para performance.            ║
║                                                                        ║
║  Criamos índices para:                                                ║
║  • Cada FK (queries sempre fazem JOIN)                                ║
║  • Combinações mais usadas (data + cliente, data + produto)           ║
║  • Campos usados em WHERE/GROUP BY                                    ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

-- Índice 1: Data (queries SEMPRE filtram por período)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_data
    ON fact.FACT_VENDAS(data_id)
    INCLUDE (valor_total_liquido, quantidade_vendida);
PRINT '  ✅ IX_FACT_VENDAS_data';
PRINT '     Uso: "Vendas do último mês", "Vendas de 2024"';

-- Índice 2: Cliente (análise de comportamento)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_cliente
    ON fact.FACT_VENDAS(cliente_id)
    INCLUDE (data_id, valor_total_liquido);
PRINT '  ✅ IX_FACT_VENDAS_cliente';
PRINT '     Uso: "Histórico de compras do cliente X"';

-- Índice 3: Produto (análise de produtos)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_produto
    ON fact.FACT_VENDAS(produto_id)
    INCLUDE (data_id, quantidade_vendida, valor_total_liquido);
PRINT '  ✅ IX_FACT_VENDAS_produto';
PRINT '     Uso: "Vendas do produto Y"';

-- Índice 4: Região (análise geográfica)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_regiao
    ON fact.FACT_VENDAS(regiao_id)
    INCLUDE (data_id, valor_total_liquido);
PRINT '  ✅ IX_FACT_VENDAS_regiao';
PRINT '     Uso: "Vendas por região"';

-- Índice 5: Vendedor (performance de vendedores)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_vendedor
    ON fact.FACT_VENDAS(vendedor_id)
    INCLUDE (data_id, valor_total_liquido, valor_comissao)
    WHERE vendedor_id IS NOT NULL;
PRINT '  ✅ IX_FACT_VENDAS_vendedor';
PRINT '     Uso: "Vendas do vendedor Z"';

-- Índice 6: Combinado Data + Produto (muito usado)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_data_produto
    ON fact.FACT_VENDAS(data_id, produto_id)
    INCLUDE (quantidade_vendida, valor_total_liquido);
PRINT '  ✅ IX_FACT_VENDAS_data_produto';
PRINT '     Uso: "Vendas de notebooks em dezembro"';

-- Índice 7: Número do pedido (lookup rápido)
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_numero_pedido
    ON fact.FACT_VENDAS(numero_pedido)
    INCLUDE (venda_id, cliente_id, data_id);
PRINT '  ✅ IX_FACT_VENDAS_numero_pedido';
PRINT '     Uso: "Buscar pedido PED-2024-123456"';

-- Índice 8: Vendas com desconto
CREATE NONCLUSTERED INDEX IX_FACT_VENDAS_com_desconto
    ON fact.FACT_VENDAS(teve_desconto, data_id)
    INCLUDE (valor_total_descontos, valor_total_liquido)
    WHERE teve_desconto = 1;
PRINT '  ✅ IX_FACT_VENDAS_com_desconto';
PRINT '     Uso: "Análise de efetividade de descontos"';

PRINT '';

-- ========================================
-- 5. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO VENDAS DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar 50 vendas realistas distribuídas em:
• Últimos 6 meses
• Diferentes clientes, produtos, regiões, vendedores
• Com e sem descontos
• Algumas com devoluções
*/

-- Declarar variáveis para geração de dados
DECLARE @i INT = 1;
DECLARE @data_id INT;
DECLARE @cliente_id INT;
DECLARE @produto_id INT;
DECLARE @regiao_id INT;
DECLARE @vendedor_id INT;
DECLARE @quantidade INT;
DECLARE @preco DECIMAL(10,2);
DECLARE @custo DECIMAL(10,2);
DECLARE @valor_total_bruto DECIMAL(15,2);
DECLARE @valor_total_descontos DECIMAL(15,2);
DECLARE @valor_total_liquido DECIMAL(15,2);
DECLARE @custo_total DECIMAL(15,2);
DECLARE @desconto_pct DECIMAL(5,2);
DECLARE @numero_ped VARCHAR(20);

PRINT 'Gerando 50 vendas...';

WHILE @i <= 50
BEGIN
    -- Selecionar data aleatória dos últimos 6 meses
    SELECT TOP 1 @data_id = data_id 
    FROM dim.DIM_DATA 
    WHERE data_completa >= DATEADD(MONTH, -6, GETDATE())
      AND data_completa <= GETDATE()
    ORDER BY NEWID();
    
    -- Selecionar cliente aleatório
    SELECT TOP 1 @cliente_id = cliente_id 
    FROM dim.DIM_CLIENTE 
    WHERE eh_ativo = 1
    ORDER BY NEWID();
    
    -- Selecionar produto aleatório
    SELECT TOP 1 
        @produto_id = produto_id,
        @preco = preco_sugerido,
        @custo = preco_custo
    FROM dim.DIM_PRODUTO 
    WHERE situacao = 'Ativo'
    ORDER BY NEWID();
    
    -- Selecionar região aleatória
    SELECT TOP 1 @regiao_id = regiao_id 
    FROM dim.DIM_REGIAO 
    ORDER BY NEWID();
    
    -- Selecionar vendedor aleatório (70% das vendas tem vendedor)
    IF RAND() < 0.7
    BEGIN
        SELECT TOP 1 @vendedor_id = vendedor_id 
        FROM dim.DIM_VENDEDOR 
        WHERE eh_ativo = 1
        ORDER BY NEWID();
    END
    ELSE
    BEGIN
        SET @vendedor_id = NULL; -- Venda direta (e-commerce)
    END
    
    -- Quantidade aleatória (1-5)
    SET @quantidade = CAST(RAND() * 4 + 1 AS INT);
    
    -- Desconto aleatório (30% das vendas tem desconto de 5-20%)
    IF RAND() < 0.3
        SET @desconto_pct = CAST(RAND() * 15 + 5 AS DECIMAL(5,2));
    ELSE
        SET @desconto_pct = 0;
    
    -- Número do pedido
    SET @numero_ped = 'PED-2024-' + RIGHT('000000' + CAST(@i AS VARCHAR), 6);
    
    -- Calcular valores já arredondados para evitar conflito com CHECK
    SET @valor_total_bruto = ROUND(@quantidade * @preco, 2);
    SET @valor_total_descontos = ROUND(@valor_total_bruto * (@desconto_pct / 100.0), 2);
    SET @valor_total_liquido = @valor_total_bruto - @valor_total_descontos;
    SET @custo_total = ROUND(@quantidade * @custo, 2);

    -- Inserir venda
    INSERT INTO fact.FACT_VENDAS (
        data_id, cliente_id, produto_id, regiao_id, vendedor_id,
        quantidade_vendida,
        preco_unitario_tabela,
        valor_total_bruto,
        valor_total_descontos,
        valor_total_liquido,
        custo_total,
        quantidade_devolvida,
        valor_devolvido,
        percentual_comissao,
        valor_comissao,
        numero_pedido,
        teve_desconto
    )
    VALUES (
        @data_id, @cliente_id, @produto_id, @regiao_id, @vendedor_id,
        @quantidade,
        @preco,
        @valor_total_bruto, -- valor bruto (2 casas)
        @valor_total_descontos, -- descontos (2 casas)
        @valor_total_liquido, -- liquido coerente
        @custo_total, -- custo (2 casas)
        0, -- sem devolução inicial
        0,
        CASE WHEN @vendedor_id IS NOT NULL THEN 3.5 ELSE NULL END, -- 3.5% comissão
        CASE WHEN @vendedor_id IS NOT NULL 
            THEN @valor_total_liquido * 0.035
            ELSE NULL 
        END,
        @numero_ped,
        CASE WHEN @desconto_pct > 0 THEN 1 ELSE 0 END
    );
    
    SET @i = @i + 1;
END

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' vendas inseridas!';
PRINT '';

-- Adicionar algumas devoluções (10% das vendas)
UPDATE TOP (5) fact.FACT_VENDAS
SET 
    quantidade_devolvida = 1,
    valor_devolvido = valor_total_liquido / quantidade_vendida
WHERE quantidade_vendida > 1;

PRINT '✅ Devoluções adicionadas!';
PRINT '';

-- ========================================
-- 6. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Tabela Fato Principal - Armazena todas as transações de venda. Granularidade: 1 item por venda.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_VENDAS';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Valor pago pelo cliente APÓS descontos. Esta é a receita real.',
    @level0type = N'SCHEMA', @level0name = 'fact',
    @level1type = N'TABLE', @level1name = 'FACT_VENDAS',
    @level2type = N'COLUMN', @level2name = 'valor_total_liquido';

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
    COUNT(*) AS total_vendas,
    SUM(quantidade_vendida) AS total_itens_vendidos,
    SUM(valor_total_bruto) AS receita_bruta,
    SUM(valor_total_descontos) AS total_descontos,
    SUM(valor_total_liquido) AS receita_liquida,
    SUM(custo_total) AS custo_total,
    SUM(valor_total_liquido) - SUM(custo_total) AS lucro_bruto,
    CAST((SUM(valor_total_liquido) - SUM(custo_total)) * 100.0 / NULLIF(SUM(valor_total_liquido), 0) AS DECIMAL(5,2)) AS margem_percentual
FROM fact.FACT_VENDAS;
PRINT '';

-- 2. Vendas por mês
PRINT '2. Vendas por Mês (últimos 6 meses):';
SELECT TOP 6
    d.ano,
    d.mes,
    d.nome_mes,
    COUNT(*) AS total_vendas,
    CAST(SUM(fv.valor_total_liquido) AS DECIMAL(15,2)) AS receita_liquida
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.ano DESC, d.mes DESC;
PRINT '';

-- 3. Top 5 produtos
PRINT '3. Top 5 Produtos Mais Vendidos:';
SELECT TOP 5
    p.nome_produto,
    p.categoria,
    SUM(fv.quantidade_vendida) AS qtd_vendida,
    CAST(SUM(fv.valor_total_liquido) AS DECIMAL(15,2)) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
GROUP BY p.nome_produto, p.categoria
ORDER BY receita DESC;
PRINT '';

-- 4. Top 5 vendedores
PRINT '4. Top 5 Vendedores:';
SELECT TOP 5
    v.nome_vendedor,
    v.cargo,
    COUNT(*) AS total_vendas,
    CAST(SUM(fv.valor_total_liquido) AS DECIMAL(15,2)) AS receita,
    CAST(SUM(fv.valor_comissao) AS DECIMAL(15,2)) AS comissao_total
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
WHERE fv.vendedor_id IS NOT NULL
GROUP BY v.nome_vendedor, v.cargo
ORDER BY receita DESC;
PRINT '';

-- 5. Vendas por regional
PRINT '5. Vendas por Regional:';
SELECT 
    e.regional,
    COUNT(DISTINCT fv.vendedor_id) AS vendedores_ativos,
    COUNT(*) AS total_vendas,
    CAST(SUM(fv.valor_total_liquido) AS DECIMAL(15,2)) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id
WHERE fv.vendedor_id IS NOT NULL
GROUP BY e.regional
ORDER BY receita DESC;
PRINT '';

-- 6. Análise de descontos
PRINT '6. Análise de Descontos:';
SELECT 
    teve_desconto,
    CASE WHEN teve_desconto = 1 THEN 'Com Desconto' ELSE 'Sem Desconto' END AS tipo,
    COUNT(*) AS total_vendas,
    CAST(AVG(valor_total_liquido) AS DECIMAL(10,2)) AS ticket_medio,
    CAST(SUM(valor_total_descontos) AS DECIMAL(15,2)) AS total_descontos
FROM fact.FACT_VENDAS
GROUP BY teve_desconto;
PRINT '';

-- 7. Taxa de devolução
PRINT '7. Análise de Devoluções:';
SELECT 
    COUNT(*) AS total_vendas,
    SUM(CASE WHEN quantidade_devolvida > 0 THEN 1 ELSE 0 END) AS vendas_com_devolucao,
    CAST(SUM(CASE WHEN quantidade_devolvida > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS taxa_devolucao_pct,
    SUM(quantidade_devolvida) AS total_itens_devolvidos,
    CAST(SUM(valor_devolvido) AS DECIMAL(15,2)) AS valor_total_devolvido
FROM fact.FACT_VENDAS;
PRINT '';

-- 8. Análise por tipo de venda (com/sem vendedor)
PRINT '8. Vendas: Diretas vs Vendedor:';
SELECT 
    CASE 
        WHEN vendedor_id IS NULL THEN 'Venda Direta (E-commerce)'
        ELSE 'Venda com Vendedor'
    END AS tipo_venda,
    COUNT(*) AS total_vendas,
    CAST(AVG(valor_total_liquido) AS DECIMAL(10,2)) AS ticket_medio,
    CAST(SUM(valor_total_liquido) AS DECIMAL(15,2)) AS receita_total
FROM fact.FACT_VENDAS
GROUP BY CASE WHEN vendedor_id IS NULL THEN 'Venda Direta (E-commerce)' ELSE 'Venda com Vendedor' END;
PRINT '';

-- ========================================
-- 8. CRIAR VIEW ANALÍTICA
-- ========================================

PRINT '========================================';
PRINT 'CRIANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('fact.VW_VENDAS_COMPLETA', 'V') IS NOT NULL
    DROP VIEW fact.VW_VENDAS_COMPLETA;
GO

CREATE VIEW fact.VW_VENDAS_COMPLETA
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_VENDAS_COMPLETA                                              ║
║  Propósito: Facilitar queries analíticas com todos os JOINs feitos    ║
║  Uso: SELECT * FROM fact.VW_VENDAS_COMPLETA WHERE ano = 2024          ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    -- IDs
    fv.venda_id,
    fv.numero_pedido,
    
    -- Data
    fv.data_id,
    d.data_completa,
    d.ano,
    d.trimestre,
    d.mes,
    d.nome_mes,
    d.dia_semana,
    d.nome_dia_semana,
    
    -- Cliente
    fv.cliente_id,
    c.nome_cliente,
    c.tipo_cliente,
    c.segmento,
    c.pais AS cliente_pais,
    c.estado AS cliente_estado,
    c.cidade AS cliente_cidade,
    
    -- Produto
    fv.produto_id,
    p.nome_produto,
    p.codigo_sku,
    p.categoria,
    p.subcategoria,
    p.marca,
    p.nome_fornecedor,
    
    -- Região de Entrega
    fv.regiao_id,
    r.cidade AS regiao_entrega_cidade,
    r.estado AS regiao_entrega_estado,
    r.regiao_pais AS regiao_entrega_regional,
    
    -- Vendedor e Equipe
    fv.vendedor_id,
    v.nome_vendedor,
    v.cargo AS vendedor_cargo,
    v.equipe_id,
    e.nome_equipe,
    e.tipo_equipe,
    e.regional AS equipe_regional,
    
    -- Métricas de Quantidade
    fv.quantidade_vendida,
    fv.quantidade_devolvida,
    fv.quantidade_vendida - fv.quantidade_devolvida AS quantidade_liquida,
    
    -- Métricas Financeiras
    fv.preco_unitario_tabela,
    fv.valor_total_bruto,
    fv.valor_total_descontos,
    fv.valor_total_liquido,
    fv.custo_total,
    fv.valor_devolvido,
    
    -- Métricas Calculadas
    fv.valor_total_liquido - fv.custo_total AS lucro_bruto,
    CASE 
        WHEN fv.valor_total_liquido > 0 
        THEN ((fv.valor_total_liquido - fv.custo_total) / fv.valor_total_liquido) * 100
        ELSE 0 
    END AS margem_percentual,
    
    fv.valor_total_liquido / fv.quantidade_vendida AS preco_medio_unitario,
    
    -- Comissões
    fv.percentual_comissao,
    fv.valor_comissao,
    
    -- Flags
    fv.teve_desconto,
    CASE WHEN fv.quantidade_devolvida > 0 THEN 1 ELSE 0 END AS teve_devolucao,
    CASE WHEN fv.vendedor_id IS NULL THEN 1 ELSE 0 END AS eh_venda_direta,
    
    -- Auditoria
    fv.data_inclusao,
    fv.data_atualizacao

FROM fact.FACT_VENDAS fv
INNER JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
INNER JOIN dim.DIM_CLIENTE c ON fv.cliente_id = c.cliente_id
INNER JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
INNER JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
LEFT JOIN dim.DIM_VENDEDOR v ON fv.vendedor_id = v.vendedor_id
LEFT JOIN dim.DIM_EQUIPE e ON v.equipe_id = e.equipe_id;
GO

PRINT '✅ View fact.VW_VENDAS_COMPLETA criada!';
PRINT '';

-- ========================================
-- 9. TESTAR A VIEW
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO VIEW ANALÍTICA';
PRINT '========================================';
PRINT '';

PRINT '1. Sample de vendas completas:';
SELECT TOP 5
    numero_pedido,
    data_completa,
    nome_cliente,
    nome_produto,
    nome_vendedor,
    CAST(valor_total_liquido AS DECIMAL(10,2)) AS valor,
    CAST(margem_percentual AS DECIMAL(5,2)) AS margem_pct
FROM fact.VW_VENDAS_COMPLETA
ORDER BY venda_id DESC;
PRINT '';

PRINT '2. Análise de margem por categoria:';
SELECT TOP 5
    categoria,
    COUNT(*) AS total_vendas,
    CAST(AVG(margem_percentual) AS DECIMAL(5,2)) AS margem_media,
    CAST(SUM(valor_total_liquido) AS DECIMAL(15,2)) AS receita_total
FROM fact.VW_VENDAS_COMPLETA
GROUP BY categoria
ORDER BY receita_total DESC;
PRINT '';

-- ========================================
-- 10. ESTATÍSTICAS FINAIS
-- ========================================

PRINT '========================================';
PRINT 'ESTATÍSTICAS FINAIS';
PRINT '========================================';
PRINT '';

SELECT 
    '📊 RESUMO DA FACT_VENDAS' AS titulo,
    (SELECT COUNT(*) FROM fact.FACT_VENDAS) AS total_vendas,
    (SELECT COUNT(DISTINCT cliente_id) FROM fact.FACT_VENDAS) AS clientes_unicos,
    (SELECT COUNT(DISTINCT produto_id) FROM fact.FACT_VENDAS) AS produtos_vendidos,
    (SELECT COUNT(DISTINCT vendedor_id) FROM fact.FACT_VENDAS WHERE vendedor_id IS NOT NULL) AS vendedores_ativos,
    (SELECT SUM(valor_total_liquido) FROM fact.FACT_VENDAS) AS receita_total,
    (SELECT AVG(valor_total_liquido) FROM fact.FACT_VENDAS) AS ticket_medio;

PRINT '';
PRINT '✅✅✅ FACT_VENDAS CRIADA E VALIDADA COM SUCESSO! ✅✅✅';
PRINT '';
PRINT '========================================';
PRINT 'RELACIONAMENTOS ESTABELECIDOS';
PRINT '========================================';
PRINT '';
PRINT '✅ FACT_VENDAS → DIM_DATA (FK data_id)';
PRINT '✅ FACT_VENDAS → DIM_CLIENTE (FK cliente_id)';
PRINT '✅ FACT_VENDAS → DIM_PRODUTO (FK produto_id)';
PRINT '✅ FACT_VENDAS → DIM_REGIAO (FK regiao_id)';
PRINT '✅ FACT_VENDAS → DIM_VENDEDOR (FK vendedor_id)';
PRINT '✅ FACT_VENDAS → DIM_EQUIPE (transitivo via DIM_VENDEDOR)';
PRINT '';
PRINT '========================================';
PRINT 'MODELO STAR SCHEMA COMPLETO!';
PRINT '========================================';
PRINT '';
PRINT '📊 DIMENSÕES CONECTADAS:';
PRINT '   • DIM_DATA ✅';
PRINT '   • DIM_CLIENTE ✅';
PRINT '   • DIM_PRODUTO ✅';
PRINT '   • DIM_REGIAO ✅';
PRINT '   • DIM_VENDEDOR ✅';
PRINT '   • DIM_EQUIPE ✅ (transitivo)';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMOS PASSOS';
PRINT '========================================';
PRINT '';
PRINT '📌 Agora você pode:';
PRINT '   1. Criar FACT_METAS (Exercício 1 - metas dos vendedores)';
PRINT '   2. Criar DIM_DESCONTO (Exercício 2)';
PRINT '   3. Criar FACT_DESCONTOS (Exercício 2)';
PRINT '   4. Criar queries analíticas avançadas';
PRINT '   5. Criar dashboards e relatórios';
PRINT '';
PRINT '🎯 QUERIES ÚTEIS:';
PRINT '   • SELECT * FROM fact.VW_VENDAS_COMPLETA';
PRINT '   • SELECT * FROM dim.VW_VENDEDORES_ATIVOS';
PRINT '   • SELECT * FROM dim.VW_EQUIPES_ATIVAS';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO SCRIPT: 08_fact_metas.sql';
PRINT '========================================';
GO


