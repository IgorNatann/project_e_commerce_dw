-- ========================================
-- SCRIPT: 07_dim_desconto.sql
-- DESCRIÇÃO: Criação da DIM_DESCONTO
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2025-12-09
-- PRÉ-REQUISITO: Todas dimensões anteriores criadas
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA DIM_DESCONTO                                           ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta dimensão armazena CUPONS, PROMOÇÕES e CAMPANHAS de desconto.    ║
║  Não confundir com os descontos APLICADOS (que vão na FACT).          ║
║                                                                        ║
║  📊 CONCEITO:                                                          ║
║  • DIM_DESCONTO = Cadastro do cupom/campanha (ex: BLACKFRIDAY)        ║
║  • FACT_DESCONTOS = Uso efetivo (BLACKFRIDAY usado na venda #123)     ║
║                                                                        ║
║  ✅ ANÁLISES POSSÍVEIS:                                                ║
║  • Quantas vezes cada cupom foi usado?                                 ║
║  • ROI de cada campanha                                                ║
║  • Quais cupons geraram mais receita?                                  ║
║  • Efetividade por tipo de desconto                                    ║
║  • Análise de período de validade                                      ║
║                                                                        ║
║  📊 RELACIONAMENTOS:                                                   ║
║  • FACT_DESCONTOS → DIM_DESCONTO (N:1)                                 ║
║  • Um cupom pode ser usado múltiplas vezes                             ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_DESCONTO';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================

IF OBJECT_ID('dim.DIM_DESCONTO', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_DESCONTO;
    PRINT ' Tabela dim.DIM_DESCONTO existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_DESCONTO
-- ========================================

PRINT 'Criando tabela dim.DIM_DESCONTO...';
PRINT '';

CREATE TABLE dim.DIM_DESCONTO
(
    -- ============================================
    -- CHAVE PRIMÁRIA (Surrogate Key)
    -- ============================================
    desconto_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============================================
    -- NATURAL KEY (Chave do Sistema Origem)
    -- ============================================
    desconto_original_id INT NOT NULL,
    -- ID do desconto no sistema promocional origem
    
    -- ============================================
    -- IDENTIFICAÇÃO DO DESCONTO
    -- ============================================
    codigo_desconto VARCHAR(50) NOT NULL,
    -- Código que o cliente digita
    -- Exemplo: "BLACKFRIDAY", "NATAL2024", "BEMVINDO10"
    -- ÚNICO por campanha
    
    nome_campanha VARCHAR(150) NULL,
    -- Nome interno da campanha
    -- Exemplo: "Black Friday 2024 - Geral"
    
    descricao VARCHAR(500) NULL,
    -- Descrição da promoção
    -- Exemplo: "10% de desconto em toda loja para Black Friday"
    
    -- ============================================
    -- TIPO E MÉTODO DO DESCONTO
    -- ============================================
    -- Por que separar tipo e método?
    -- • TIPO: natureza do desconto
    -- • MÉTODO: como é calculado
    -- ============================================
    
    tipo_desconto VARCHAR(30) NOT NULL,
    -- Categoria do desconto:
    --   'Cupom' - código digitado pelo cliente
    --   'Promoção Automática' - aplicada automaticamente
    --   'Desconto Progressivo' - baseado em valor/quantidade
    --   'Fidelidade' - programa de pontos
    --   'Primeira Compra' - novo cliente
    --   'Cashback' - devolução pós-compra
    
    metodo_desconto VARCHAR(30) NOT NULL,
    -- Como é calculado:
    --   'Percentual' - X% de desconto
    --   'Valor Fixo' - R$ X de desconto
    --   'Frete Grátis' - remove custo de frete
    --   'Brinde' - produto grátis
    --   'Combo' - compre X leve Y
    
    -- ============================================
    -- VALOR DO DESCONTO
    -- ============================================
    -- Por que nullable?
    -- • Frete grátis não tem "valor" fixo
    -- • Descontos progressivos variam
    -- ============================================
    
    valor_desconto DECIMAL(10,2) NULL,
    -- Valor do desconto (sentido depende do método)
    -- Se percentual: 10.00 = 10%
    -- Se fixo: 50.00 = R$50 de desconto
    -- Se combo: NULL (regra específica)
    
    -- ============================================
    -- REGRAS DE APLICAÇÃO
    -- ============================================
    -- Condições para o desconto ser válido
    -- ============================================
    
    min_valor_compra_regra DECIMAL(15,2) NULL,
    -- Valor mínimo do pedido para usar o desconto
    -- Exemplo: R$ 200,00 (só vale acima desse valor)
    -- NULL = sem mínimo
    
    max_valor_desconto_regra DECIMAL(15,2) NULL,
    -- Teto do desconto (para percentuais)
    -- Exemplo: 10% com teto de R$100 (não desconta mais que isso)
    -- NULL = sem teto
    
    max_usos_por_cliente INT NULL,
    -- Quantas vezes cada cliente pode usar
    -- Exemplo: 1 = uso único por cliente
    -- NULL = uso ilimitado
    
    max_usos_total INT NULL,
    -- Limite global de usos do cupom
    -- Exemplo: 1000 = apenas os primeiros 1000 clientes
    -- NULL = ilimitado
    
    -- ============================================
    -- ONDE APLICA
    -- ============================================
    
    aplica_em VARCHAR(30) NOT NULL,
    -- Escopo do desconto:
    --   'Pedido Total' - desconto no carrinho inteiro
    --   'Produto Específico' - só em produtos selecionados
    --   'Categoria' - só em categorias específicas
    --   'Frete' - apenas no frete
    --   'Item Individual' - por item no carrinho
    
    restricao_produtos VARCHAR(500) NULL,
    -- Lista de produtos/categorias elegíveis
    -- Exemplo: "Notebooks,Tablets" ou "Eletrônicos"
    -- NULL = todos os produtos
    
    restricao_clientes VARCHAR(500) NULL,
    -- Restrições de quem pode usar
    -- Exemplo: "Novos Clientes", "VIP", "Corporativo"
    -- NULL = todos os clientes
    
    -- ============================================
    -- VALIDADE TEMPORAL
    -- ============================================
    -- Todo desconto tem começo e fim
    -- ============================================
    
    data_inicio_validade DATETIME NOT NULL,
    -- Quando o cupom começa a valer
    
    data_fim_validade DATETIME NULL,
    -- Quando o cupom expira
    -- NULL = sem data de expiração
    
    -- ============================================
    -- ORIGEM E CANAL
    -- ============================================
    
    origem_campanha VARCHAR(50) NULL,
    -- De onde veio a campanha:
    --   'Marketing Digital'
    --   'Email Marketing'
    --   'Influenciador'
    --   'Parceria'
    --   'Programa Fidelidade'
    
    canal_divulgacao VARCHAR(50) NULL,
    -- Onde foi divulgado:
    --   'Instagram'
    --   'Google Ads'
    --   'Email'
    --   'Site'
    --   'App'
    
    -- ============================================
    -- CONTROLE DE USO
    -- ============================================
    -- Snapshots atualizados pelo ETL
    -- ============================================
    
    total_usos_realizados INT NOT NULL DEFAULT 0,
    -- Quantas vezes foi usado até agora
    -- Atualizado pela FACT_DESCONTOS
    
    total_receita_gerada DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Soma de todas vendas que usaram este desconto
    -- Atualizado pela FACT_DESCONTOS
    
    total_desconto_concedido DECIMAL(15,2) NOT NULL DEFAULT 0,
    -- Quanto de desconto foi dado no total
    -- Atualizado pela FACT_DESCONTOS
    
    -- ============================================
    -- STATUS E CONTROLE
    -- ============================================
    
    situacao VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    -- Status do cupom:
    --   'Ativo' - pode ser usado
    --   'Pausado' - temporariamente desabilitado
    --   'Expirado' - passou da validade
    --   'Esgotado' - atingiu limite de usos
    --   'Cancelado' - desabilitado manualmente
    
    eh_ativo BIT NOT NULL DEFAULT 1,
    -- 0 = Não pode mais ser usado
    -- 1 = Disponível para uso
    
    requer_aprovacao BIT NOT NULL DEFAULT 0,
    -- 0 = Aplicado automaticamente
    -- 1 = Precisa aprovação manual (grandes descontos)
    
    eh_cumulativo BIT NOT NULL DEFAULT 0,
    -- 0 = Não pode combinar com outros descontos
    -- 1 = Pode acumular com outras promoções
    
    -- ============================================
    -- AUDITORIA
    -- ============================================
    
    data_criacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Quando o cupom foi criado
    
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Última modificação
    
    usuario_criador VARCHAR(100) NULL,
    -- Quem criou a campanha
    
    -- ============================================
    -- OBSERVAÇÕES
    -- ============================================
    
    observacoes VARCHAR(500) NULL,
    -- Notas internas sobre a campanha
    
    -- ============================================
    -- CONSTRAINTS
    -- ============================================
    
    CONSTRAINT PK_DIM_DESCONTO 
        PRIMARY KEY CLUSTERED (desconto_id),
    
    -- Unique: Código do desconto deve ser único
    CONSTRAINT UK_DIM_DESCONTO_codigo 
        UNIQUE (codigo_desconto),
    
    -- Unique: ID original único
    CONSTRAINT UK_DIM_DESCONTO_original_id 
        UNIQUE (desconto_original_id),
    
    -- Check: Valor de desconto positivo (se informado)
    CONSTRAINT CK_DIM_DESCONTO_valor_positivo 
        CHECK (valor_desconto > 0 OR valor_desconto IS NULL),
    
    -- Check: Data fim deve ser após início
    CONSTRAINT CK_DIM_DESCONTO_datas_logicas 
        CHECK (data_fim_validade IS NULL OR data_fim_validade >= data_inicio_validade),
    
    -- Check: Situação válida
    CONSTRAINT CK_DIM_DESCONTO_situacao 
        CHECK (situacao IN ('Ativo', 'Pausado', 'Expirado', 'Esgotado', 'Cancelado')),
    
    -- Check: Tipo válido
    CONSTRAINT CK_DIM_DESCONTO_tipo 
        CHECK (tipo_desconto IN ('Cupom', 'Promoção Automática', 'Desconto Progressivo', 'Fidelidade', 'Primeira Compra', 'Cashback')),
    
    -- Check: Método válido
    CONSTRAINT CK_DIM_DESCONTO_metodo 
        CHECK (metodo_desconto IN ('Percentual', 'Valor Fixo', 'Frete Grátis', 'Brinde', 'Combo')),
    
    -- Check: Aplica em - valor válido
    CONSTRAINT CK_DIM_DESCONTO_aplica_em 
        CHECK (aplica_em IN ('Pedido Total', 'Produto Específico', 'Categoria', 'Frete', 'Item Individual'))
);
GO

PRINT ' Tabela dim.DIM_DESCONTO criada com sucesso!';
PRINT '';
PRINT ' Estrutura:';
PRINT '   • Chave Primária: desconto_id (surrogate)';
PRINT '   • Chave Natural: desconto_original_id';
PRINT '   • Identificação: codigo_desconto (ÚNICO)';
PRINT '   • Tipos: cupom, promoção, progressivo, fidelidade';
PRINT '   • Métodos: percentual, fixo, frete grátis, brinde';
PRINT '   • Regras: mínimo, máximo, limites de uso';
PRINT '   • Validade: início e fim';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

-- Índice 1: Busca por código (usado pelo cliente)
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_codigo
    ON dim.DIM_DESCONTO(codigo_desconto)
    INCLUDE (desconto_id, situacao, eh_ativo, data_fim_validade);
PRINT '  IX_DIM_DESCONTO_codigo';
PRINT '     Uso: Validar cupom digitado pelo cliente';

-- Índice 2: Busca por ID original (ETL)
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_original_id
    ON dim.DIM_DESCONTO(desconto_original_id)
    INCLUDE (desconto_id, codigo_desconto);
PRINT ' IX_DIM_DESCONTO_original_id';
PRINT '     Uso: Processo ETL';

-- Índice 3: Filtro por situação
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_situacao
    ON dim.DIM_DESCONTO(situacao, eh_ativo)
    INCLUDE (desconto_id, codigo_desconto, data_fim_validade);
PRINT ' IX_DIM_DESCONTO_situacao';
PRINT '     Uso: Listar cupons ativos';

-- Índice 4: Busca por tipo
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_tipo
    ON dim.DIM_DESCONTO(tipo_desconto)
    INCLUDE (desconto_id, codigo_desconto, valor_desconto);
PRINT '   IX_DIM_DESCONTO_tipo';
PRINT '     Uso: Análise por tipo de desconto';

-- Índice 5: Filtro por validade
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_validade
    ON dim.DIM_DESCONTO(data_inicio_validade, data_fim_validade)
    INCLUDE (desconto_id, codigo_desconto, situacao)
    WHERE eh_ativo = 1;
PRINT '   IX_DIM_DESCONTO_validade';
PRINT '     Uso: Cupons válidos hoje';

-- Índice 6: Performance (total usos)
CREATE NONCLUSTERED INDEX IX_DIM_DESCONTO_performance
    ON dim.DIM_DESCONTO(total_usos_realizados)
    INCLUDE (desconto_id, codigo_desconto, total_receita_gerada)
    WHERE total_usos_realizados > 0;
PRINT '   IX_DIM_DESCONTO_performance';
PRINT '     Uso: Ranking de cupons mais usados';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO DESCONTOS DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar descontos variados:
• Cupons promocionais (Black Friday, Natal)
• Descontos progressivos
• Frete grátis
• Primeira compra
• Fidelidade
*/

-- Desconto 1: Black Friday (Percentual)
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    min_valor_compra_regra, max_valor_desconto_regra, max_usos_por_cliente,
    max_usos_total, aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, canal_divulgacao, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    1, 'BLACKFRIDAY2024', 'Black Friday 2024', '15% de desconto em toda loja',
    'Cupom', 'Percentual', 15.00,
    200.00, 300.00, 1,
    NULL, 'Pedido Total', '2024-11-25T00:00:00', '2024-11-29T23:59:59',
    'Marketing Digital', 'Instagram', 'Expirado', 0, 0
);


-- Desconto 2: Primeira Compra
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    min_valor_compra_regra, max_usos_por_cliente,
    aplica_em, restricao_clientes, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    2, 'BEMVINDO10', 'Bem-vindo novos clientes', '10% desconto primeira compra',
    'Primeira Compra', 'Percentual', 10.00,
    100.00, 1,
    'Pedido Total', 'Novos Clientes', '2024-01-01 00:00:00', NULL,
    'Programa Fidelidade', 'Ativo', 1, 0
);

-- Desconto 3: Frete Grátis
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    min_valor_compra_regra, max_valor_desconto_regra, max_usos_por_cliente,
    aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    3, 'FRETEGRATIS', 'Frete Grátis Sul/Sudeste', 'Frete grátis acima R$150',
    'Promoção Automática', 'Frete Grátis', NULL,
    150.00, NULL, NULL,
    'Frete', '20240601 00:00:00', '20241231 23:59:59',
    'Marketing Digital', 'Ativo', 1, 1
);


-- Desconto 4: Natal (Valor Fixo)
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    min_valor_compra_regra, max_usos_por_cliente, max_usos_total,
    aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, canal_divulgacao, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    4, 'NATAL50', 'Natal 2024 - R$50 OFF', 'R$50 de desconto compras acima de R$300',
    'Cupom', 'Valor Fixo', 50.00,
    300.00, 1, 5000,
    'Pedido Total', '20241215 00:00:00', '20241226 23:59:59',
    'Email Marketing', 'Email', 'Ativo', 1, 0
);

-- Desconto 5: VIP (Percentual alto)
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    aplica_em, restricao_clientes, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo, requer_aprovacao
)
VALUES (
    5, 'VIP20', 'Desconto Clientes VIP', '20% para clientes VIP',
    'Fidelidade', 'Percentual', 20.00,
    'Pedido Total', 'VIP', '2024-01-01 00:00:00', NULL,
    'Programa Fidelidade', 'Ativo', 1, 1, 0
);

-- Desconto 6: Desconto Progressivo
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    min_valor_compra_regra,
    aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    6, 'PROGRESSIVO500', 'Desconto Progressivo', '5% acima R$500',
    'Desconto Progressivo', 'Percentual', 5.00,
    500.00,
    'Pedido Total', '2024-01-01 00:00:00', NULL,
    'Promoção Interna', 'Ativo', 1, 1
);

-- Desconto 7: Categoria Específica
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    aplica_em, restricao_produtos, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    7, 'ELETRO12', 'Promoção Eletrônicos', '12% em Eletrônicos',
    'Cupom', 'Percentual', 12.00,
    'Categoria', 'Eletrônicos,Informática', '20241101 00:00:00', '20241130 23:59:59',
    'Marketing Digital', 'Ativo', 1, 0
);

-- Desconto 8: Influenciador
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    max_usos_total,
    aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, canal_divulgacao, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    8, 'INFLUENCER15', 'Parceria Influencer XYZ', '15% para seguidores',
    'Cupom', 'Percentual', 15.00,
    1000,
    'Pedido Total', '20241001 00:00:00', '20241231 23:59:59',
    'Influenciador', 'Instagram', 'Ativo', 1, 0
);

-- Desconto 9: Cashback
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto, valor_desconto,
    aplica_em, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    9, 'CASHBACK5', 'Cashback 5%', '5% de volta para próxima compra',
    'Cashback', 'Percentual', 5.00,
    'Pedido Total', '2024-01-01 00:00:00', NULL,
    'Programa Fidelidade', 'Ativo', 1, 1
);

-- Desconto 10: Combo (Brinde)
INSERT INTO dim.DIM_DESCONTO (
    desconto_original_id, codigo_desconto, nome_campanha, descricao,
    tipo_desconto, metodo_desconto,
    aplica_em, restricao_produtos, data_inicio_validade, data_fim_validade,
    origem_campanha, situacao, eh_ativo, eh_cumulativo
)
VALUES (
    10, 'COMBO3X2', 'Compre 3 Pague 2', 'Na compra de 3 unidades, pague apenas 2',
    'Cupom', 'Combo',
    'Produto Específico', 'Categoria Especial', '20241201 00:00:00', '20241231 23:59:59',
    'Promoção Interna', 'Ativo', 1, 0
);

PRINT ' ' + CAST(@@ROWCOUNT AS VARCHAR) + ' descontos inseridos!';
PRINT '';

-- ========================================
-- 5. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão de Descontos - Armazena cupons, promoções e campanhas de desconto.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_DESCONTO';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Código digitado pelo cliente para ativar o desconto. Deve ser único.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_DESCONTO',
    @level2type = N'COLUMN', @level2name = 'codigo_desconto';

PRINT ' Documentação adicionada!';
PRINT '';

-- ========================================
-- 6. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- 1. Total geral
PRINT '1. Resumo Geral:';
SELECT 
    COUNT(*) AS total_descontos,
    SUM(CASE WHEN eh_ativo = 1 THEN 1 ELSE 0 END) AS descontos_ativos,
    SUM(CASE WHEN situacao = 'Expirado' THEN 1 ELSE 0 END) AS expirados
FROM dim.DIM_DESCONTO;
PRINT '';

-- 2. Por tipo
PRINT '2. Descontos por Tipo:';
SELECT 
    tipo_desconto,
    COUNT(*) AS total,
    SUM(CASE WHEN eh_ativo = 1 THEN 1 ELSE 0 END) AS ativos
FROM dim.DIM_DESCONTO
GROUP BY tipo_desconto
ORDER BY total DESC;
PRINT '';

-- 3. Por método
PRINT '3. Descontos por Método:';
SELECT 
    metodo_desconto,
    COUNT(*) AS total,
    AVG(valor_desconto) AS valor_medio
FROM dim.DIM_DESCONTO
WHERE valor_desconto IS NOT NULL
GROUP BY metodo_desconto
ORDER BY total DESC;
PRINT '';

-- 4. Ativos agora
PRINT '4. Descontos Válidos Hoje:';
SELECT 
    codigo_desconto,
    tipo_desconto,
    metodo_desconto,
    valor_desconto,
    data_fim_validade
FROM dim.DIM_DESCONTO
WHERE eh_ativo = 1
  AND data_inicio_validade <= GETDATE()
  AND (data_fim_validade IS NULL OR data_fim_validade >= GETDATE())
ORDER BY data_inicio_validade DESC;
PRINT '';

-- 5. Por situação
PRINT '5. Descontos por Situação:';
SELECT 
    situacao,
    COUNT(*) AS total
FROM dim.DIM_DESCONTO
GROUP BY situacao
ORDER BY total DESC;
PRINT '';

-- 6. Listagem completa
PRINT '6. Amostra de Descontos:';
SELECT 
    desconto_id,
    codigo_desconto,
    tipo_desconto,
    metodo_desconto,
    valor_desconto,
    situacao
FROM dim.DIM_DESCONTO
ORDER BY desconto_id;
PRINT '';

-- ========================================
-- 7. CRIAR VIEW AUXILIAR
-- ========================================

PRINT '========================================';
PRINT 'CRIANDO VIEW AUXILIAR';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('dim.VW_DESCONTOS_ATIVOS', 'V') IS NOT NULL
    DROP VIEW dim.VW_DESCONTOS_ATIVOS;
GO

CREATE VIEW dim.VW_DESCONTOS_ATIVOS
AS
/*
╔════════════════════════════════════════════════════════════════════════╗
║  View: VW_DESCONTOS_ATIVOS                                             ║
║  Propósito: Mostrar apenas descontos válidos e utilizáveis            ║
║  Uso: SELECT * FROM dim.VW_DESCONTOS_ATIVOS                           ║
╚════════════════════════════════════════════════════════════════════════╝
*/
SELECT 
    desconto_id,
    desconto_original_id,
    codigo_desconto,
    nome_campanha,
    descricao,
    tipo_desconto,
    metodo_desconto,
    valor_desconto,
    -- Regras
    min_valor_compra_regra,
    max_valor_desconto_regra,
    max_usos_por_cliente,
    max_usos_total,
    aplica_em,
    restricao_produtos,
    restricao_clientes,
    -- Validade
    data_inicio_validade,
    data_fim_validade,
    CASE 
        WHEN data_fim_validade IS NULL THEN 'Sem Expiração'
        WHEN data_fim_validade >= GETDATE() THEN 'Válido'
        ELSE 'Expirado'
    END AS status_validade,
    DATEDIFF(DAY, GETDATE(), data_fim_validade) AS dias_ate_expirar,
    -- Performance
    total_usos_realizados,
    total_receita_gerada,
    total_desconto_concedido,
    -- Controle
    origem_campanha,
    canal_divulgacao,
    eh_cumulativo,
    requer_aprovacao,
    -- Cálculos
    CASE 
        WHEN total_usos_realizados > 0 
        THEN total_receita_gerada / total_usos_realizados
        ELSE 0
    END AS ticket_medio_com_desconto,
    CASE 
        WHEN total_usos_realizados > 0 
        THEN total_desconto_concedido / total_usos_realizados
        ELSE 0
    END AS desconto_medio_por_uso
FROM dim.DIM_DESCONTO
WHERE eh_ativo = 1 
  AND situacao = 'Ativo'
  AND data_inicio_validade <= GETDATE()
  AND (data_fim_validade IS NULL OR data_fim_validade >= GETDATE());
GO

PRINT '✅ View dim.VW_DESCONTOS_ATIVOS criada!';
PRINT '';

-- ========================================
-- 8. TESTAR VIEW
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO VIEW';
PRINT '========================================';
PRINT '';

PRINT 'Descontos Válidos:';
SELECT 
    codigo_desconto,
    tipo_desconto,
    CAST(valor_desconto AS VARCHAR) + '%' AS desconto,
    status_validade,
    dias_ate_expirar
FROM dim.VW_DESCONTOS_ATIVOS
ORDER BY dias_ate_expirar;
PRINT '';

-- ========================================
-- 9. ESTATÍSTICAS FINAIS
-- ========================================

PRINT '========================================';
PRINT 'ESTATÍSTICAS FINAIS';
PRINT '========================================';
PRINT '';

SELECT 
    '📊 RESUMO DA DIM_DESCONTO' AS titulo,
    (SELECT COUNT(*) FROM dim.DIM_DESCONTO) AS total_descontos,
    (SELECT COUNT(*) FROM dim.DIM_DESCONTO WHERE eh_ativo = 1) AS ativos,
    (SELECT COUNT(*) FROM dim.VW_DESCONTOS_ATIVOS) AS validos_hoje,
    (SELECT COUNT(DISTINCT tipo_desconto) FROM dim.DIM_DESCONTO) AS tipos_diferentes,
    (SELECT COUNT(DISTINCT metodo_desconto) FROM dim.DIM_DESCONTO) AS metodos_diferentes;

PRINT '';
PRINT '✅✅✅ DIM_DESCONTO CRIADA E VALIDADA COM SUCESSO! ✅✅✅';
PRINT '';
PRINT '========================================';
PRINT 'ESTRUTURA COMPLETA';
PRINT '========================================';
PRINT '';
PRINT '📋 Campos principais:';
PRINT '   • Identificação: codigo_desconto, nome_campanha';
PRINT '   • Tipo: cupom, promoção, progressivo, fidelidade, cashback';
PRINT '   • Método: percentual, fixo, frete grátis, brinde, combo';
PRINT '   • Regras: mínimo, máximo, limites de uso';
PRINT '   • Validade: data início e fim';
PRINT '   • Aplicação: pedido, produto, categoria, frete';
PRINT '   • Performance: usos, receita, desconto concedido';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO PASSO';
PRINT '========================================';
PRINT '';
PRINT '📌 Agora vamos criar:';
PRINT '   FACT_DESCONTOS - Registro de uso de cada desconto';
PRINT '';
PRINT '🔗 Esta FACT vai conectar:';
PRINT '   • FACT_DESCONTOS → DIM_DESCONTO (qual cupom?)';
PRINT '   • FACT_DESCONTOS → FACT_VENDAS (em qual venda?)';
PRINT '   • FACT_DESCONTOS → DIM_DATA (quando?)';
PRINT '   • FACT_DESCONTOS → DIM_CLIENTE (quem usou?)';
PRINT '   • FACT_DESCONTOS → DIM_PRODUTO (em qual produto?)';
PRINT '';
PRINT '🎯 Análises que vamos conseguir fazer:';
PRINT '   • Quantas vezes cada cupom foi usado?';
PRINT '   • Qual cupom gerou mais receita?';
PRINT '   • Qual o ROI de cada campanha?';
PRINT '   • Como descontos afetam a margem?';
PRINT '   • Quais produtos têm mais desconto?';
PRINT '   • Análise temporal de uso de cupons';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO SCRIPT: 10_fact_descontos.sql';
PRINT '========================================';
GO