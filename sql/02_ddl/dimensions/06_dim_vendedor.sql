-- ========================================
-- SCRIPT: 06_dim_vendedor.sql
-- DESCRIÇÃO: Criação da DIM_VENDEDOR
-- AUTOR: Data Warehouse E-commerce Project
-- DATA: 2024-12-06
-- PRÉ-REQUISITO: 05_dim_equipe.sql executado
-- ========================================

/*
╔════════════════════════════════════════════════════════════════════════╗
║  🎯 OBJETIVO DA DIM_VENDEDOR                                           ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Esta dimensão armazena informações sobre VENDEDORES individuais.     ║
║  É a ponte entre vendas e equipes/metas.                              ║
║                                                                        ║
║  ✅ Análises possíveis:                                                ║
║     • Performance individual de vendedores                             ║
║     • Comparação vendedor vs vendedor                                  ║
║     • Vendedores vs suas metas                                         ║
║     • Análise de turnover (contratação/desligamento)                   ║
║     • Comissionamento por vendedor                                     ║
║                                                                        ║
║  📊 RELACIONAMENTOS:                                                   ║
║  • DIM_VENDEDOR → DIM_EQUIPE (N:1) [vendedor pertence a equipe]       ║
║  • DIM_VENDEDOR → DIM_VENDEDOR (N:1) [vendedor tem gerente]           ║
║  • DIM_EQUIPE → DIM_VENDEDOR (1:1) [equipe tem líder]                 ║
║  • FACT_VENDAS → DIM_VENDEDOR (N:1) [venda feita por vendedor]        ║
║  • FACT_METAS → DIM_VENDEDOR (N:1) [meta de um vendedor]              ║
║                                                                        ║
║  ⚠️  IMPORTANTE - DEPENDÊNCIA CIRCULAR:                                ║
║  DIM_EQUIPE tem lider_equipe_id que aponta para esta tabela.          ║
║  Resolução: lider_equipe_id aceita NULL até popular vendedores.       ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

USE DW_ECOMMERCE;
GO

PRINT '========================================';
PRINT 'CRIAÇÃO DA DIM_VENDEDOR';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1. DROPAR TABELA SE EXISTIR
-- ========================================
IF OBJECT_ID('dim.DIM_VENDEDOR', 'U') IS NOT NULL
BEGIN
    DROP TABLE dim.DIM_VENDEDOR;
    PRINT '⚠️  Tabela dim.DIM_VENDEDOR existente foi dropada.';
    PRINT '';
END

-- ========================================
-- 2. CRIAR TABELA DIM_VENDEDOR
-- ========================================

PRINT 'Criando tabela dim.DIM_VENDEDOR...';
PRINT '';

CREATE TABLE dim.DIM_VENDEDOR
(
    -- ============================================
    -- CHAVE PRIMÁRIA (Surrogate Key)
    -- ============================================
    vendedor_id INT IDENTITY(1,1) NOT NULL,
    
    -- ============================================
    -- NATURAL KEY (Chave do Sistema Origem)
    -- ============================================
    vendedor_original_id INT NOT NULL,
    -- ID do vendedor no sistema de RH/CRM origem
    
    -- ============================================
    -- IDENTIFICAÇÃO PESSOAL
    -- ============================================
    nome_vendedor VARCHAR(150) NOT NULL,
    -- Nome completo do vendedor
    
    nome_exibicao VARCHAR(50) NULL,
    -- Nome curto/apelido usado no sistema
    -- Exemplo: "João Silva" → "João S."
    
    cpf VARCHAR(14) NULL,
    -- Formato: 000.000.000-00
    -- NULL para privacidade ou vendedores externos
    
    matricula VARCHAR(20) NULL,
    -- Matrícula funcional da empresa
    -- Exemplo: "VND2024001"
    
    -- ============================================
    -- CONTATO
    -- ============================================
    email VARCHAR(255) NOT NULL,
    -- Email corporativo principal
    
    email_pessoal VARCHAR(255) NULL,
    -- Email pessoal (backup)
    
    telefone_celular VARCHAR(20) NULL,
    -- Formato: (11) 99999-9999
    
    telefone_comercial VARCHAR(20) NULL,
    -- Ramal ou telefone fixo
    
    -- ============================================
    -- CARGO E HIERARQUIA
    -- ============================================
    cargo VARCHAR(50) NOT NULL,
    -- Valores comuns:
    --   'Vendedor Júnior'
    --   'Vendedor Pleno'
    --   'Vendedor Sênior'
    --   'Coordenador de Vendas'
    --   'Gerente de Vendas'
    
    nivel_senioridade VARCHAR(20) NULL,
    -- Júnior, Pleno, Sênior, Especialista, Gerente
    
    departamento VARCHAR(50) NULL,
    -- 'Vendas', 'Comercial', 'E-commerce', etc
    
    area VARCHAR(50) NULL,
    -- Área dentro do departamento
    -- Exemplo: 'B2B', 'B2C', 'Corporativo'
    
    -- ============================================
    -- RELACIONAMENTO COM EQUIPE
    -- ============================================
    -- Por que FK para equipe?
    -- • Vendedor pertence a UMA equipe por vez
    -- • Permite análise: "performance da Equipe Alpha"
    -- • Relacionamento transitivo evitado na FACT
    -- ============================================
    equipe_id INT NULL,
    -- FK para DIM_EQUIPE
    -- NULL = vendedor sem equipe atribuída (novo/em transição)
    
    nome_equipe VARCHAR(100) NULL,
    -- DESNORMALIZADO para performance
    -- Atualizado quando equipe muda
    
    -- ============================================
    -- HIERARQUIA GERENCIAL (Self-Referencing)
    -- ============================================
    -- Por que self-join?
    -- • Vendedor pode ter um gerente que também é vendedor
    -- • Cria árvore hierárquica: CEO → Diretor → Gerente → Vendedor
    -- ============================================
    gerente_id INT NULL,
    -- FK para DIM_VENDEDOR (auto-referência)
    -- NULL = vendedor não tem gerente (é o topo)
    
    nome_gerente VARCHAR(150) NULL,
    -- DESNORMALIZADO para performance
    
    -- ============================================
    -- LOCALIZAÇÃO E TERRITÓRIO
    -- ============================================
    estado_atuacao CHAR(2) NULL,
    -- Estado principal de atuação
    -- Exemplo: 'SP', 'RJ', 'MG'
    
    cidade_atuacao VARCHAR(100) NULL,
    -- Cidade base do vendedor
    
    territorio_vendas VARCHAR(100) NULL,
    -- Descrição do território
    -- Exemplo: "Grande SP", "Interior RJ", "Nordeste"
    
    tipo_vendedor VARCHAR(30) NULL,
    -- Classificação:
    --   'Interno' (escritório)
    --   'Externo' (campo)
    --   'Híbrido'
    --   'Remoto'
    
    -- ============================================
    -- METAS E COMISSIONAMENTO
    -- ============================================
    -- Por que meta base aqui?
    -- • Esta é a meta PADRÃO mensal do vendedor
    -- • FACT_METAS terá valores REAIS por período
    -- • Facilita relatórios: "quem está abaixo da meta base?"
    -- ============================================
    meta_mensal_base DECIMAL(15,2) NULL,
    -- Meta padrão de vendas (R$) por mês
    
    meta_trimestral_base DECIMAL(15,2) NULL,
    -- Meta padrão trimestral
    
    percentual_comissao_padrao DECIMAL(5,2) NULL,
    -- % de comissão padrão sobre vendas
    -- Exemplo: 3.50 = 3.5%
    
    tipo_comissao VARCHAR(30) NULL,
    -- 'Fixa' (mesmo % sempre)
    -- 'Variável' (depende de meta)
    -- 'Escalonada' (aumenta com volume)
    
    -- ============================================
    -- PERFORMANCE HISTÓRICA (Snapshot)
    -- ============================================
    -- Por que armazenar histórico aqui?
    -- • Para comparações rápidas sem calcular
    -- • Atualizado mensalmente pelo ETL
    -- ATENÇÃO: Dados reais estão na FACT_VENDAS!
    -- ============================================
    total_vendas_mes_atual DECIMAL(15,2) NULL,
    -- Total vendido no mês corrente (até agora)
    
    total_vendas_mes_anterior DECIMAL(15,2) NULL,
    -- Total vendido no último mês fechado
    
    percentual_meta_mes_anterior DECIMAL(5,2) NULL,
    -- % da meta atingida no último mês
    
    ranking_mes_anterior INT NULL,
    -- Posição no ranking do mês passado
    
    total_vendas_acumulado_ano DECIMAL(15,2) NULL,
    -- Total vendido no ano corrente
    
    -- ============================================
    -- DATAS DE CONTROLE
    -- ============================================
    data_contratacao DATE NOT NULL,
    -- Quando o vendedor foi contratado
    
    data_primeira_venda DATE NULL,
    -- Quando fez a primeira venda (marco)
    
    data_ultima_venda DATE NULL,
    -- Última venda registrada (detectar inatividade)
    
    data_desligamento DATE NULL,
    -- Se foi desligado, quando foi?
    
    data_ultima_atualizacao DATETIME NOT NULL DEFAULT GETDATE(),
    -- Última vez que registro foi modificado
    
    -- ============================================
    -- STATUS E FLAGS
    -- ============================================
    situacao VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    -- Valores possíveis:
    --   'Ativo' (trabalhando normalmente)
    --   'Afastado' (férias, licença)
    --   'Suspenso' (problemas disciplinares)
    --   'Desligado' (não trabalha mais)
    
    eh_ativo BIT NOT NULL DEFAULT 1,
    -- 0 = Inativo, 1 = Ativo
    -- Campo booleano para filtros rápidos
    
    eh_lider BIT NOT NULL DEFAULT 0,
    -- 0 = Vendedor comum, 1 = Líder de equipe
    -- Para identificar quem é líder
    
    aceita_novos_clientes BIT NOT NULL DEFAULT 1,
    -- 0 = Não, 1 = Sim
    -- Para controle de distribuição de leads
    
    -- ============================================
    -- OBSERVAÇÕES
    -- ============================================
    observacoes VARCHAR(500) NULL,
    -- Notas sobre o vendedor
    -- Exemplo: "Especialista em clientes corporativos"
    
    motivo_desligamento VARCHAR(200) NULL,
    -- Se desligado, qual foi o motivo?
    
    -- ============================================
    -- CONSTRAINTS (Regras de Integridade)
    -- ============================================
    
    -- Primary Key
    CONSTRAINT PK_DIM_VENDEDOR 
        PRIMARY KEY CLUSTERED (vendedor_id),
    
    -- Unique: Não pode ter 2 vendedores com mesmo ID original
    CONSTRAINT UK_DIM_VENDEDOR_original_id 
        UNIQUE (vendedor_original_id),
    
    -- Unique: Email corporativo deve ser único
    CONSTRAINT UK_DIM_VENDEDOR_email 
        UNIQUE (email),
    
    -- Unique: Matrícula deve ser única (se informada)
    CONSTRAINT UK_DIM_VENDEDOR_matricula 
        UNIQUE (matricula),
    
    -- Check: Meta não pode ser negativa
    CONSTRAINT CK_DIM_VENDEDOR_meta_positiva 
        CHECK (meta_mensal_base >= 0 OR meta_mensal_base IS NULL),
    
    -- Check: % comissão entre 0 e 100
    CONSTRAINT CK_DIM_VENDEDOR_comissao_valida 
        CHECK (percentual_comissao_padrao BETWEEN 0 AND 100 OR percentual_comissao_padrao IS NULL),
    
    -- Check: Situação deve ser valor válido
    CONSTRAINT CK_DIM_VENDEDOR_situacao 
        CHECK (situacao IN ('Ativo', 'Afastado', 'Suspenso', 'Desligado')),
    
    -- Check: Data desligamento deve ser após contratação
    CONSTRAINT CK_DIM_VENDEDOR_datas_logicas 
        CHECK (data_desligamento IS NULL OR data_desligamento >= data_contratacao),
    
    -- Foreign Key: Equipe
    CONSTRAINT FK_DIM_VENDEDOR_equipe 
        FOREIGN KEY (equipe_id) 
        REFERENCES dim.DIM_EQUIPE(equipe_id),
    
    -- Foreign Key: Gerente (self-referencing)
    CONSTRAINT FK_DIM_VENDEDOR_gerente 
        FOREIGN KEY (gerente_id) 
        REFERENCES dim.DIM_VENDEDOR(vendedor_id)
);
GO

PRINT '✅ Tabela dim.DIM_VENDEDOR criada com sucesso!';
PRINT '';
PRINT '📊 Estrutura:';
PRINT '   • Chave Primária: vendedor_id (surrogate)';
PRINT '   • Chave Natural: vendedor_original_id';
PRINT '   • FK Equipe: equipe_id → DIM_EQUIPE';
PRINT '   • FK Gerente: gerente_id → DIM_VENDEDOR (self-join)';
PRINT '   • Metas base: mensal e trimestral';
PRINT '   • Performance: snapshots atualizados pelo ETL';
PRINT '';

-- ========================================
-- 3. CRIAR ÍNDICES
-- ========================================

PRINT 'Criando índices para performance...';
PRINT '';

/*
╔════════════════════════════════════════════════════════════════════════╗
║  📚 ESTRATÉGIA DE INDEXAÇÃO                                            ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Índices nos campos mais usados em:                                   ║
║  • JOINs (equipe_id, gerente_id)                                      ║
║  • WHERE (situacao, eh_ativo, estado)                                 ║
║  • ORDER BY (nome, ranking)                                           ║
║  • Lookups ETL (original_id, email, matricula)                        ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
*/

-- Índice 1: Busca por ID original (usado no ETL)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_original_id 
    ON dim.DIM_VENDEDOR(vendedor_original_id)
    INCLUDE (vendedor_id, nome_vendedor, email, situacao);
PRINT '  ✅ IX_DIM_VENDEDOR_original_id';
PRINT '     Uso: Lookup no processo ETL para atualizar vendedores';

-- Índice 2: Busca por equipe (queries analíticas)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_equipe 
    ON dim.DIM_VENDEDOR(equipe_id)
    INCLUDE (vendedor_id, nome_vendedor, cargo, meta_mensal_base)
    WHERE equipe_id IS NOT NULL;
PRINT '  ✅ IX_DIM_VENDEDOR_equipe';
PRINT '     Uso: "Listar vendedores da Equipe Alpha"';

-- Índice 3: Busca por gerente (hierarquia)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_gerente 
    ON dim.DIM_VENDEDOR(gerente_id)
    INCLUDE (vendedor_id, nome_vendedor, cargo)
    WHERE gerente_id IS NOT NULL;
PRINT '  ✅ IX_DIM_VENDEDOR_gerente';
PRINT '     Uso: "Vendedores do gerente João"';

-- Índice 4: Busca por situação (filtrar ativos)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_situacao 
    ON dim.DIM_VENDEDOR(situacao, eh_ativo)
    INCLUDE (vendedor_id, nome_vendedor, equipe_id);
PRINT '  ✅ IX_DIM_VENDEDOR_situacao';
PRINT '     Uso: Filtrar apenas vendedores ativos';

-- Índice 5: Busca por nome (autocomplete, pesquisas)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_nome 
    ON dim.DIM_VENDEDOR(nome_vendedor)
    INCLUDE (vendedor_id, email, cargo, equipe_id);
PRINT '  ✅ IX_DIM_VENDEDOR_nome';
PRINT '     Uso: Busca textual por nome em interfaces';

-- Índice 6: Busca por email (login, validações)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_email 
    ON dim.DIM_VENDEDOR(email)
    INCLUDE (vendedor_id, nome_vendedor);
PRINT '  ✅ IX_DIM_VENDEDOR_email';
PRINT '     Uso: Validar emails únicos, sistemas de login';

-- Índice 7: Busca por estado (análise regional)
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_estado 
    ON dim.DIM_VENDEDOR(estado_atuacao)
    INCLUDE (vendedor_id, nome_vendedor, equipe_id)
    WHERE estado_atuacao IS NOT NULL;
PRINT '  ✅ IX_DIM_VENDEDOR_estado';
PRINT '     Uso: "Vendedores de SP"';

-- Índice 8: Busca por líderes
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_lideres 
    ON dim.DIM_VENDEDOR(eh_lider, eh_ativo)
    INCLUDE (vendedor_id, nome_vendedor, equipe_id)
    WHERE eh_lider = 1;
PRINT '  ✅ IX_DIM_VENDEDOR_lideres';
PRINT '     Uso: Listar apenas líderes de equipe';

-- Índice 9: CPF único quando informado (índice filtrado)
CREATE UNIQUE NONCLUSTERED INDEX IX_DIM_VENDEDOR_cpf 
    ON dim.DIM_VENDEDOR(cpf)
    WHERE cpf IS NOT NULL;
PRINT '   IX_DIM_VENDEDOR_cpf';
PRINT '     Uso: Garantir unicidade de CPF apenas quando preenchido';

-- �?ndice 10: Performance snapshot
CREATE NONCLUSTERED INDEX IX_DIM_VENDEDOR_performance 
    ON dim.DIM_VENDEDOR(ranking_mes_anterior)
    INCLUDE (vendedor_id, nome_vendedor, total_vendas_mes_anterior)
    WHERE ranking_mes_anterior IS NOT NULL AND eh_ativo = 1;
PRINT '  ✅ IX_DIM_VENDEDOR_performance';
PRINT '     Uso: Rankings e leaderboards';

PRINT '';

-- ========================================
-- 4. POPULAR COM DADOS DE EXEMPLO
-- ========================================

PRINT '========================================';
PRINT 'INSERINDO VENDEDORES DE EXEMPLO';
PRINT '========================================';
PRINT '';

/*
Vamos criar vendedores para as equipes existentes:
• Equipe 1 (Alpha SP): 8 vendedores
• Equipe 2 (Beta RJ): 6 vendedores  
• Equipe 3 (Gamma MG): 5 vendedores
• Outras: alguns vendedores
*/

-- ============================================
-- VENDEDORES DA EQUIPE ALPHA SP (equipe_id = 1)
-- ============================================

-- Vendedor 1: Líder da Equipe Alpha
INSERT INTO dim.DIM_VENDEDOR (
    vendedor_original_id, nome_vendedor, nome_exibicao, matricula,
    email, telefone_celular,
    cargo, nivel_senioridade, departamento, area,
    equipe_id, nome_equipe,
    estado_atuacao, cidade_atuacao, tipo_vendedor,
    meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao,
    data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes
)
VALUES (
    1, 'Carlos Eduardo Silva', 'Carlos S.', 'VND2022001',
    'carlos.silva@ecommerce.com.br', '(11) 98765-4321',
    'Gerente de Vendas', 'Gerente', 'Vendas', 'B2B',
    1, 'Equipe Alpha SP',
    'SP', 'São Paulo', 'Híbrido',
    80000.00, 240000.00, 5.00, 'Escalonada',
    '2022-01-10', 'Ativo', 1, 1, 1
);

-- Vendedor 2: Sênior da Alpha
INSERT INTO dim.DIM_VENDEDOR (
    vendedor_original_id, nome_vendedor, nome_exibicao, matricula,
    email, telefone_celular,
    cargo, nivel_senioridade, departamento, area,
    equipe_id, nome_equipe, gerente_id, nome_gerente,
    estado_atuacao, cidade_atuacao, tipo_vendedor,
    meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao,
    data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes
)
VALUES (
    2, 'Ana Paula Santos', 'Ana P.', 'VND2022015',
    'ana.santos@ecommerce.com.br', '(11) 98765-1111',
    'Vendedor Sênior', 'Sênior', 'Vendas', 'B2B',
    1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva',
    'SP', 'São Paulo', 'Externo',
    65000.00, 195000.00, 4.50, 'Variável',
    '2022-03-15', 'Ativo', 1, 0, 1
);

-- Vendedor 3: Pleno da Alpha
INSERT INTO dim.DIM_VENDEDOR (
    vendedor_original_id, nome_vendedor, nome_exibicao, matricula,
    email, telefone_celular,
    cargo, nivel_senioridade, departamento, area,
    equipe_id, nome_equipe, gerente_id, nome_gerente,
    estado_atuacao, cidade_atuacao, tipo_vendedor,
    meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao,
    data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes
)
VALUES (
    3, 'Roberto Almeida', 'Roberto A.', 'VND2023008',
    'roberto.almeida@ecommerce.com.br', '(11) 98765-2222',
    'Vendedor Pleno', 'Pleno', 'Vendas', 'B2B',
    1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva',
    'SP', 'Campinas', 'Externo',
    55000.00, 165000.00, 4.00, 'Variável',
    '2023-02-20', 'Ativo', 1, 0, 1
);

-- Vendedores 4-8: Júniores da Alpha
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, telefone_celular, cargo, nivel_senioridade, departamento, area, equipe_id, nome_equipe, gerente_id, nome_gerente, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES 
(4, 'Juliana Costa', 'Juliana C.', 'VND2023045', 'juliana.costa@ecommerce.com.br', '(11) 98765-3333', 'Vendedor Júnior', 'Júnior', 'Vendas', 'B2B', 1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva', 'SP', 'São Paulo', 'Interno', 45000.00, 135000.00, 3.50, 'Fixa', '2023-07-01', 'Ativo', 1, 0, 1),
(5, 'Fernando Oliveira', 'Fernando O.', 'VND2023067', 'fernando.oliveira@ecommerce.com.br', '(11) 98765-4444', 'Vendedor Júnior', 'Júnior', 'Vendas', 'B2B', 1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva', 'SP', 'São Paulo', 'Híbrido', 45000.00, 135000.00, 3.50, 'Fixa', '2023-09-15', 'Ativo', 1, 0, 1),
(6, 'Mariana Ribeiro', 'Mariana R.', 'VND2024003', 'mariana.ribeiro@ecommerce.com.br', '(11) 98765-5555', 'Vendedor Júnior', 'Júnior', 'Vendas', 'B2B', 1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva', 'SP', 'Santos', 'Externo', 42000.00, 126000.00, 3.50, 'Fixa', '2024-01-08', 'Ativo', 1, 0, 1),
(7, 'Paulo Henrique Souza', 'Paulo H.', 'VND2024012', 'paulo.souza@ecommerce.com.br', '(11) 98765-6666', 'Vendedor Júnior', 'Júnior', 'Vendas', 'B2B', 1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva', 'SP', 'São Paulo', 'Interno', 42000.00, 126000.00, 3.50, 'Fixa', '2024-03-01', 'Ativo', 1, 0, 1),
(8, 'Beatriz Lima', 'Beatriz L.', 'VND2024025', 'beatriz.lima@ecommerce.com.br', '(11) 98765-7777', 'Vendedor Júnior', 'Júnior', 'Vendas', 'B2B', 1, 'Equipe Alpha SP', 1, 'Carlos Eduardo Silva', 'SP', 'São Bernardo', 'Externo', 40000.00, 120000.00, 3.50, 'Fixa', '2024-06-01', 'Ativo', 1, 0, 1);

-- ============================================
-- VENDEDORES DA EQUIPE BETA RJ (equipe_id = 2)
-- ============================================

-- Vendedor 9: Líder da Equipe Beta (Inside Sales)
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, telefone_celular, cargo, nivel_senioridade, departamento, area, equipe_id, nome_equipe, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES (9, 'Luciana Fernandes', 'Luciana F.', 'VND2023002', 'luciana.fernandes@ecommerce.com.br', '(21) 98888-1111', 'Coordenador de Vendas', 'Sênior', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 'RJ', 'Rio de Janeiro', 'Remoto', 60000.00, 180000.00, 4.50, 'Variável', '2023-03-10', 'Ativo', 1, 1, 1);

-- Vendedores 10-14: Time Beta RJ
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, telefone_celular, cargo, nivel_senioridade, departamento, area, equipe_id, nome_equipe, gerente_id, nome_gerente, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES 
(10, 'Rafael Santos', 'Rafael S.', 'VND2023025', 'rafael.santos@ecommerce.com.br', '(21) 98888-2222', 'Vendedor Pleno', 'Pleno', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 9, 'Luciana Fernandes', 'RJ', 'Rio de Janeiro', 'Remoto', 50000.00, 150000.00, 4.00, 'Fixa', '2023-05-20', 'Ativo', 1, 0, 1),
(11, 'Camila Rodrigues', 'Camila R.', 'VND2023034', 'camila.rodrigues@ecommerce.com.br', '(21) 98888-3333', 'Vendedor Pleno', 'Pleno', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 9, 'Luciana Fernandes', 'RJ', 'Niterói', 'Remoto', 50000.00, 150000.00, 4.00, 'Fixa', '2023-06-15', 'Ativo', 1, 0, 1),
(12, 'Diego Martins', 'Diego M.', 'VND2023089', 'diego.martins@ecommerce.com.br', '(21) 98888-4444', 'Vendedor Júnior', 'Júnior', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 9, 'Luciana Fernandes', 'RJ', 'Rio de Janeiro', 'Remoto', 40000.00, 120000.00, 3.50, 'Fixa', '2023-10-01', 'Ativo', 1, 0, 1),
(13, 'Gabriela Pereira', 'Gabriela P.', 'VND2024007', 'gabriela.pereira@ecommerce.com.br', '(21) 98888-5555', 'Vendedor Júnior', 'Júnior', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 9, 'Luciana Fernandes', 'RJ', 'Rio de Janeiro', 'Remoto', 38000.00, 114000.00, 3.50, 'Fixa', '2024-02-01', 'Ativo', 1, 0, 1),
(14, 'Thiago Alves', 'Thiago A.', 'VND2024018', 'thiago.alves@ecommerce.com.br', '(21) 98888-6666', 'Vendedor Júnior', 'Júnior', 'Vendas', 'Inside Sales', 2, 'Time Beta RJ', 9, 'Luciana Fernandes', 'RJ', 'Rio de Janeiro', 'Remoto', 38000.00, 114000.00, 3.50, 'Fixa', '2024-04-15', 'Ativo', 1, 0, 1);

-- ============================================
-- VENDEDORES DA EQUIPE GAMMA MG (equipe_id = 3) - KEY ACCOUNTS
-- ============================================

-- Vendedor 15: Líder Key Accounts
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, telefone_celular, cargo, nivel_senioridade, departamento, area, equipe_id, nome_equipe, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES (15, 'Marcelo Carvalho', 'Marcelo C.', 'VND2022005', 'marcelo.carvalho@ecommerce.com.br', '(31) 99777-1111', 'Gerente Key Accounts', 'Especialista', 'Vendas', 'Corporativo', 3, 'Equipe Gamma MG', 'MG', 'Belo Horizonte', 'Híbrido', 120000.00, 360000.00, 6.00, 'Escalonada', '2022-06-01', 'Ativo', 1, 1, 1);

-- Vendedores 16-19: Key Accounts
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, telefone_celular, cargo, nivel_senioridade, departamento, area, equipe_id, nome_equipe, gerente_id, nome_gerente, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, meta_trimestral_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES 
(16, 'Patricia Mendes', 'Patricia M.', 'VND2022018', 'patricia.mendes@ecommerce.com.br', '(31) 99777-2222', 'Vendedor Sênior', 'Sênior', 'Vendas', 'Corporativo', 3, 'Equipe Gamma MG', 15, 'Marcelo Carvalho', 'MG', 'Belo Horizonte', 'Externo', 100000.00, 300000.00, 5.50, 'Escalonada', '2022-08-10', 'Ativo', 1, 0, 0),
(17, 'Rodrigo Barbosa', 'Rodrigo B.', 'VND2023011', 'rodrigo.barbosa@ecommerce.com.br', '(31) 99777-3333', 'Vendedor Sênior', 'Sênior', 'Vendas', 'Corporativo', 3, 'Equipe Gamma MG', 15, 'Marcelo Carvalho', 'MG', 'Contagem', 'Externo', 95000.00, 285000.00, 5.50, 'Escalonada', '2023-03-05', 'Ativo', 1, 0, 0),
(18, 'Vanessa Lima', 'Vanessa L.', 'VND2023056', 'vanessa.lima@ecommerce.com.br', '(31) 99777-4444', 'Vendedor Pleno', 'Pleno', 'Vendas', 'Corporativo', 3, 'Equipe Gamma MG', 15, 'Marcelo Carvalho', 'MG', 'Belo Horizonte', 'Híbrido', 80000.00, 240000.00, 5.00, 'Variável', '2023-08-20', 'Ativo', 1, 0, 1),
(19, 'Bruno Costa', 'Bruno C.', 'VND2024009', 'bruno.costa@ecommerce.com.br', '(31) 99777-5555', 'Vendedor Pleno', 'Pleno', 'Vendas', 'Corporativo', 3, 'Equipe Gamma MG', 15, 'Marcelo Carvalho', 'MG', 'Betim', 'Externo', 75000.00, 225000.00, 5.00, 'Variável', '2024-02-10', 'Ativo', 1, 0, 1);

-- ============================================
-- VENDEDORES DE OUTRAS EQUIPES (resumido)
-- ============================================

-- Equipe 4 (Delta RS) - Líder + 2 vendedores
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, cargo, nivel_senioridade, equipe_id, nome_equipe, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES 
(20, 'Amanda Silva', 'Amanda S.', 'VND2023040', 'amanda.silva@ecommerce.com.br', 'Coordenador de Vendas', 'Pleno', 4, 'Time Delta RS', 'RS', 'Porto Alegre', 'Híbrido', 45000.00, 4.00, 'Variável', '2023-08-20', 'Ativo', 1, 1, 1),
(21, 'Lucas Ferreira', 'Lucas F.', 'VND2023078', 'lucas.ferreira@ecommerce.com.br', 'Vendedor Pleno', 'Pleno', 4, 'Time Delta RS', 'RS', 'Porto Alegre', 'Externo', 40000.00, 3.50, 'Fixa', '2023-09-15', 'Ativo', 1, 0, 1),
(22, 'Tatiana Souza', 'Tatiana S.', 'VND2024020', 'tatiana.souza@ecommerce.com.br', 'Vendedor Júnior', 'Júnior', 4, 'Time Delta RS', 'RS', 'Canoas', 'Interno', 35000.00, 3.50, 'Fixa', '2024-05-01', 'Ativo', 1, 0, 1);

-- Equipe 5 (Digital) - E-commerce Team
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, cargo, nivel_senioridade, equipe_id, nome_equipe, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, situacao, eh_ativo, eh_lider, aceita_novos_clientes)
VALUES 
(23, 'Felipe Araujo', 'Felipe A.', 'VND2022003', 'felipe.araujo@ecommerce.com.br', 'Gerente E-commerce', 'Gerente', 5, 'Equipe Digital', 'SP', 'São Paulo', 'Remoto', 100000.00, 5.00, 'Escalonada', '2022-01-15', 'Ativo', 1, 1, 1),
(24, 'Aline Martins', 'Aline M.', 'VND2022034', 'aline.martins@ecommerce.com.br', 'Vendedor Sênior', 'Sênior', 5, 'Equipe Digital', 'SP', 'São Paulo', 'Remoto', 70000.00, 4.50, 'Variável', '2022-04-10', 'Ativo', 1, 0, 1),
(25, 'Renato Dias', 'Renato D.', 'VND2023019', 'renato.dias@ecommerce.com.br', 'Vendedor Pleno', 'Pleno', 5, 'Equipe Digital', 'RJ', 'Rio de Janeiro', 'Remoto', 55000.00, 4.00, 'Fixa', '2023-04-01', 'Ativo', 1, 0, 1);

-- Vendedor DESLIGADO (exemplo histórico)
INSERT INTO dim.DIM_VENDEDOR (vendedor_original_id, nome_vendedor, nome_exibicao, matricula, email, cargo, nivel_senioridade, equipe_id, nome_equipe, estado_atuacao, cidade_atuacao, tipo_vendedor, meta_mensal_base, percentual_comissao_padrao, tipo_comissao, data_contratacao, data_desligamento, situacao, eh_ativo, eh_lider, aceita_novos_clientes, motivo_desligamento)
VALUES (26, 'José Antônio Pereira', 'José A.', 'VND2022099', 'jose.pereira@ecommerce.com.br', 'Vendedor Pleno', 'Pleno', 1, 'Equipe Alpha SP', 'SP', 'São Paulo', 'Externo', 50000.00, 4.00, 'Fixa', '2022-05-01', '2024-08-31', 'Desligado', 0, 0, 0, 'Pedido de demissão - Nova oportunidade');

PRINT '✅ ' + CAST(@@ROWCOUNT AS VARCHAR) + ' vendedores inseridos!';
PRINT '';

-- ========================================
-- 5. ATUALIZAR DIM_EQUIPE COM LÍDERES
-- ========================================

PRINT '========================================';
PRINT 'ATUALIZANDO LÍDERES NAS EQUIPES';
PRINT '========================================';
PRINT '';

/*
Agora que temos vendedores, podemos atualizar as equipes
para apontar quem é o líder de cada uma.
*/

UPDATE dim.DIM_EQUIPE 
SET lider_equipe_id = 1, nome_lider = 'Carlos Eduardo Silva', email_lider = 'carlos.silva@ecommerce.com.br'
WHERE equipe_id = 1;

UPDATE dim.DIM_EQUIPE 
SET lider_equipe_id = 9, nome_lider = 'Luciana Fernandes', email_lider = 'luciana.fernandes@ecommerce.com.br'
WHERE equipe_id = 2;

UPDATE dim.DIM_EQUIPE 
SET lider_equipe_id = 15, nome_lider = 'Marcelo Carvalho', email_lider = 'marcelo.carvalho@ecommerce.com.br'
WHERE equipe_id = 3;

UPDATE dim.DIM_EQUIPE 
SET lider_equipe_id = 20, nome_lider = 'Amanda Silva', email_lider = 'amanda.silva@ecommerce.com.br'
WHERE equipe_id = 4;

UPDATE dim.DIM_EQUIPE 
SET lider_equipe_id = 23, nome_lider = 'Felipe Araujo', email_lider = 'felipe.araujo@ecommerce.com.br'
WHERE equipe_id = 5;

PRINT '✅ Líderes atualizados em DIM_EQUIPE!';
PRINT '';

-- ========================================
-- 6. ADICIONAR DOCUMENTAÇÃO
-- ========================================

PRINT 'Adicionando documentação estendida...';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'Dimensão de Vendedores - Armazena informações sobre vendedores individuais, hierarquia e performance.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_VENDEDOR';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'FK para DIM_EQUIPE - Indica a qual equipe o vendedor pertence.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_VENDEDOR',
    @level2type = N'COLUMN', @level2name = 'equipe_id';

EXEC sys.sp_addextendedproperty 
    @name = N'Description',
    @value = N'FK self-referencing - Indica quem é o gerente direto deste vendedor.',
    @level0type = N'SCHEMA', @level0name = 'dim',
    @level1type = N'TABLE', @level1name = 'DIM_VENDEDOR',
    @level2type = N'COLUMN', @level2name = 'gerente_id';

PRINT '✅ Documentação adicionada!';
PRINT '';

-- ========================================
-- 7. QUERIES DE VALIDAÇÃO
-- ========================================

PRINT '========================================';
PRINT 'VALIDAÇÃO DOS DADOS';
PRINT '========================================';
PRINT '';

-- 1. Total de vendedores
PRINT '1. Total de Vendedores:';
SELECT 
    COUNT(*) AS total_vendedores,
    SUM(CASE WHEN eh_ativo = 1 THEN 1 ELSE 0 END) AS ativos,
    SUM(CASE WHEN eh_ativo = 0 THEN 1 ELSE 0 END) AS inativos,
    SUM(CASE WHEN eh_lider = 1 THEN 1 ELSE 0 END) AS lideres
FROM dim.DIM_VENDEDOR;
PRINT '';

-- 2. Distribuição por equipe
PRINT '2. Vendedores por Equipe:';
SELECT 
    e.nome_equipe,
    COUNT(v.vendedor_id) AS total_vendedores,
    SUM(v.meta_mensal_base) AS meta_total,
    AVG(v.meta_mensal_base) AS meta_media
FROM dim.DIM_EQUIPE e
LEFT JOIN dim.DIM_VENDEDOR v ON e.equipe_id = v.equipe_id AND v.eh_ativo = 1
GROUP BY e.nome_equipe
ORDER BY total_vendedores DESC;
PRINT '';

-- 3. Distribuição por cargo
PRINT '3. Vendedores por Cargo:';
SELECT 
    cargo,
    COUNT(*) AS total,
    AVG(meta_mensal_base) AS meta_media
FROM dim.DIM_VENDEDOR
WHERE eh_ativo = 1
GROUP BY cargo
ORDER BY meta_media DESC;
PRINT '';

-- 4. Distribuição por senioridade
PRINT '4. Vendedores por Senioridade:';
SELECT 
    nivel_senioridade,
    COUNT(*) AS total,
    AVG(meta_mensal_base) AS meta_media,
    AVG(percentual_comissao_padrao) AS comissao_media
FROM dim.DIM_VENDEDOR
WHERE eh_ativo = 1 AND nivel_senioridade IS NOT NULL
GROUP BY nivel_senioridade
ORDER BY meta_media DESC;
PRINT '';

-- 5. Top 10 vendedores por meta
PRINT '5. Top 10 Vendedores por Meta:';
SELECT TOP 10
    nome_vendedor,
    cargo,
    nome_equipe,
    CAST(meta_mensal_base AS DECIMAL(15,2)) AS meta_mensal,
    CAST(percentual_comissao_padrao AS DECIMAL(5,2)) AS comissao_pct
FROM dim.DIM_VENDEDOR
WHERE eh_ativo = 1
ORDER BY meta_mensal_base DESC;
PRINT '';

-- 6. Hierarquia - Líderes e seus subordinados
PRINT '6. Hierarquia (amostra):';
SELECT 
    v.nome_vendedor AS vendedor,
    v.cargo,
    g.nome_vendedor AS gerente,
    v.nome_equipe
FROM dim.DIM_VENDEDOR v
LEFT JOIN dim.DIM_VENDEDOR g ON v.gerente_id = g.vendedor_id
WHERE v.eh_ativo = 1
ORDER BY v.equipe_id, v.eh_lider DESC, v.nome_vendedor;
PRINT '';

-- 7. Análise por tipo de vendedor
PRINT '7. Por Tipo de Vendedor:';
SELECT 
    tipo_vendedor,
    COUNT(*) AS total,
    AVG(meta_mensal_base) AS meta_media
FROM dim.DIM_VENDEDOR
WHERE eh_ativo = 1 AND tipo_vendedor IS NOT NULL
GROUP BY tipo_vendedor
ORDER BY total DESC;
PRINT '';

-- 8. Distribuição por estado
PRINT '8. Vendedores por Estado:';
SELECT 
    estado_atuacao,
    COUNT(*) AS total_vendedores
FROM dim.DIM_VENDEDOR
WHERE eh_ativo = 1 AND estado_atuacao IS NOT NULL
GROUP BY estado_atuacao
ORDER BY total_vendedores DESC;
PRINT '';

-- ========================================
-- 8. VIEWS AUXILIARES (CENTRALIZADAS)
-- ========================================

PRINT '========================================';
PRINT 'VIEWS AUXILIARES CENTRALIZADAS';
PRINT '========================================';
PRINT '';
PRINT 'As views dim.VW_VENDEDORES_ATIVOS, dim.VW_HIERARQUIA_VENDEDORES e';
PRINT 'dim.VW_ANALISE_EQUIPE_VENDEDORES sao criadas em sql/04_views';
PRINT '(script master: 04_master_views.sql).';
PRINT '';

-- ========================================
-- 9. TESTES BASE (SEM DEPENDER DE VIEWS)
-- ========================================

PRINT '========================================';
PRINT 'TESTANDO CONSULTAS BASE DA DIM_VENDEDOR';
PRINT '========================================';
PRINT '';

PRINT '1. Vendedores Ativos (sample):';
SELECT TOP 5
    v.nome_vendedor,
    v.cargo,
    v.nome_equipe,
    CASE
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 6 THEN 'Novato (<6m)'
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 12 THEN 'Junior (6-12m)'
        WHEN DATEDIFF(MONTH, v.data_contratacao, GETDATE()) < 24 THEN 'Intermediario (1-2a)'
        ELSE 'Veterano (2a+)'
    END AS tempo_casa_categoria
FROM dim.DIM_VENDEDOR v
WHERE v.eh_ativo = 1 AND v.situacao = 'Ativo'
ORDER BY v.meta_mensal_base DESC;
PRINT '';

PRINT '2. Hierarquia (lideres):';
SELECT
    v.nome_vendedor,
    v.cargo,
    v.nome_equipe,
    CASE
        WHEN v.gerente_id IS NULL THEN 1
        WHEN g1.gerente_id IS NULL THEN 2
        WHEN g2.gerente_id IS NULL THEN 3
        ELSE 4
    END AS nivel_hierarquico
FROM dim.DIM_VENDEDOR v
LEFT JOIN dim.DIM_VENDEDOR g1 ON v.gerente_id = g1.vendedor_id
LEFT JOIN dim.DIM_VENDEDOR g2 ON g1.gerente_id = g2.vendedor_id
WHERE v.eh_lider = 1 AND v.eh_ativo = 1;
PRINT '';

PRINT '3. Analise por Equipe:';
SELECT
    e.nome_equipe,
    COUNT(v.vendedor_id) AS total_vendedores,
    SUM(CASE WHEN v.nivel_senioridade COLLATE Latin1_General_CI_AI = 'Junior' THEN 1 ELSE 0 END) AS juniors,
    SUM(CASE WHEN v.nivel_senioridade = 'Pleno' THEN 1 ELSE 0 END) AS plenos,
    SUM(CASE WHEN v.nivel_senioridade COLLATE Latin1_General_CI_AI IN ('Senior', 'Especialista', 'Gerente') THEN 1 ELSE 0 END) AS seniors,
    CAST(AVG(v.meta_mensal_base) AS DECIMAL(15,2)) AS meta_media
FROM dim.DIM_EQUIPE e
LEFT JOIN dim.DIM_VENDEDOR v
    ON e.equipe_id = v.equipe_id
   AND v.eh_ativo = 1
WHERE e.eh_ativa = 1
GROUP BY e.nome_equipe
ORDER BY total_vendedores DESC;
PRINT '';

-- ========================================
-- 10. ESTATÍSTICAS FINAIS
-- ========================================

PRINT '========================================';
PRINT 'ESTATÍSTICAS FINAIS';
PRINT '========================================';
PRINT '';

SELECT 
    '📊 RESUMO DA DIM_VENDEDOR' AS titulo,
    (SELECT COUNT(*) FROM dim.DIM_VENDEDOR) AS total_registros,
    (SELECT COUNT(*) FROM dim.DIM_VENDEDOR WHERE eh_ativo = 1) AS vendedores_ativos,
    (SELECT COUNT(*) FROM dim.DIM_VENDEDOR WHERE eh_lider = 1) AS total_lideres,
    (SELECT SUM(meta_mensal_base) FROM dim.DIM_VENDEDOR WHERE eh_ativo = 1) AS soma_todas_metas,
    (SELECT AVG(meta_mensal_base) FROM dim.DIM_VENDEDOR WHERE eh_ativo = 1) AS meta_media,
    (SELECT COUNT(DISTINCT equipe_id) FROM dim.DIM_VENDEDOR WHERE eh_ativo = 1) AS equipes_com_vendedores;

PRINT '';
PRINT '✅✅✅ DIM_VENDEDOR CRIADA E VALIDADA COM SUCESSO! ✅✅✅';
PRINT '';
PRINT '========================================';
PRINT 'RELACIONAMENTOS ESTABELECIDOS';
PRINT '========================================';
PRINT '';
PRINT '✅ DIM_VENDEDOR → DIM_EQUIPE (FK equipe_id)';
PRINT '✅ DIM_VENDEDOR → DIM_VENDEDOR (FK gerente_id - self-join)';
PRINT '✅ DIM_EQUIPE → DIM_VENDEDOR (FK lider_equipe_id - atualizado!)';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMOS PASSOS';
PRINT '========================================';
PRINT '';
PRINT '📌 Agora você pode:';
PRINT '   1. Atualizar FACT_VENDAS (adicionar coluna vendedor_id)';
PRINT '   2. Popular FACT_VENDAS com dados de vendas';
PRINT '   3. Criar FACT_METAS';
PRINT '   4. Criar DIM_DESCONTO';
PRINT '   5. Criar FACT_DESCONTOS';
PRINT '';
PRINT '🔗 Relacionamentos pendentes:';
PRINT '   • FACT_VENDAS.vendedor_id → DIM_VENDEDOR.vendedor_id';
PRINT '   • FACT_METAS.vendedor_id → DIM_VENDEDOR.vendedor_id';
PRINT '';
PRINT '========================================';
PRINT 'PRÓXIMO SCRIPT: 07_fact_vendas_update.sql';
PRINT '========================================';
GO
