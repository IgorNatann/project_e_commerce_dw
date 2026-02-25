# 📖 Dicionário de Dados - DW E-commerce

> Catálogo completo de todos os campos, tipos e significados

## 📋 Índice

- [Como Usar Este Documento](#como-usar-este-documento)
- [Convenções e Padrões](#convenções-e-padrões)
- [Dimensões](#dimensões)
- [Tabelas Fato](#tabelas-fato)
- [Views Auxiliares](#views-auxiliares)
- [Glossário de Termos](#glossário-de-termos)

---

## 📚 Como Usar Este Documento

### Estrutura das Entradas

Cada campo está documentado com:

| Elemento | Descrição |
|----------|-----------|
| **Campo** | Nome técnico do campo |
| **Tipo** | Tipo de dados SQL Server |
| **Obrigatório** | NULL ou NOT NULL |
| **Descrição** | O que o campo representa |
| **Exemplo** | Valor válido ou exemplo |
| **Regras** | Constraints e validações |

**Origem:** quando aplicável, indicada no rodapé de cada tabela.


### Navegação Rápida

- 🔑 = Primary Key
- 🔗 = Foreign Key
- 📊 = Métrica (medida)
- 📝 = Atributo descritivo
- 🏷️ = Flag (booleano)
- 🗓️ = Campo temporal

---

## 📐 Convenções e Padrões

### Nomenclatura

```
Padrão de Nomes:
├─ Tabelas: MAIÚSCULAS com prefixo (DIM_, FACT_)
├─ Campos: snake_case (minúsculas com underscore)
├─ PKs: [tabela]_id (ex: cliente_id)
├─ FKs: mesmo nome da PK referenciada
└─ Views: prefixo VW_
```

### Tipos de Dados

| Tipo SQL Server | Uso | Exemplo |
|----------------|-----|---------|
| `INT` | IDs, contadores | `cliente_id INT` |
| `BIGINT` | IDs de facts (grande volume) | `venda_id BIGINT` |
| `VARCHAR(n)` | Textos variáveis | `nome_cliente VARCHAR(200)` |
| `CHAR(n)` | Textos fixos | `estado CHAR(2)` |
| `DECIMAL(p,s)` | Valores monetários | `valor_total DECIMAL(15,2)` |
| `DATE` | Datas | `data_cadastro DATE` |
| `DATETIME` | Data+hora | `data_inclusao DATETIME` |
| `BIT` | Booleanos | `eh_ativo BIT` |

### Surrogate Keys

**Padrão:** INT IDENTITY(1,1)

- Todas dimensões: `[tabela]_id INT`
- Todas facts: `[tabela]_id BIGINT`
- Sempre incremento automático
- Sempre NOT NULL PRIMARY KEY

---

## 📐 DIMENSÕES

## DIM_DATA - Dimensão Temporal

**Schema:** `dim.DIM_DATA`  
**Registros:** Variável (de `2020-01-01` até `31/12/(ano_atual + 5)`)  
**Crescimento:** Dinâmico e automático (o script recalcula o intervalo com base no ano corrente)

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **data_id** | INT | ✓ | PK surrogate (IDENTITY) | `1` | PRIMARY KEY |
| 🗓️ **data_completa** | DATE | ✓ | Data completa | `2024-12-31` | UNIQUE |
| 📝 **ano** | INT | ✓ | Ano (4 dígitos) | `2024` | `>= 2020` |
| 📝 **trimestre** | INT | ✓ | Trimestre do ano | `4` | `BETWEEN 1 AND 4` |
| 📝 **mes** | INT | ✓ | Mês (1-12) | `12` | `BETWEEN 1 AND 12` |
| 📝 **dia** | INT | ✓ | Dia do mês | `31` | `BETWEEN 1 AND 31` |
| 📝 **semana_do_ano** | INT | ✓ | Semana do ano | `52` | `BETWEEN 1 AND 53` |
| 📝 **dia_da_semana** | INT | ✓ | Dia da semana (1=Dom) | `7` | `BETWEEN 1 AND 7` |
| 📝 **nome_mes** | VARCHAR(20) | ✓ | Nome do mês | `Dezembro` | - |
| 📝 **nome_mes_abrev** | VARCHAR(3) | ✓ | Abreviação do mês | `Dez` | - |
| 📝 **nome_dia_semana** | VARCHAR(20) | ✓ | Nome do dia | `Sábado` | - |
| 📝 **nome_dia_semana_abrev** | VARCHAR(3) | ✓ | Abreviação do dia | `Sáb` | - |
| 🏷️ **eh_fim_de_semana** | BIT | ✓ | Flag fim de semana | `1` | 1=Sim, 0=Não |
| 🏷️ **eh_feriado** | BIT | ✓ | Flag feriado nacional | `1` | 1=Sim, 0=Não |
| 📝 **nome_feriado** | VARCHAR(50) | ✗ | Nome do feriado | `Natal` | NULL se não feriado |
| 📝 **dia_do_ano** | INT | ✓ | Dia do ano (ordinal) | `365` | `BETWEEN 1 AND 366` |
| 🏷️ **eh_ano_bissexto** | BIT | ✓ | Ano bissexto | `1` | 1=Sim, 0=Não |
| 📝 **periodo_mes** | VARCHAR(7) | ✓ | Ano-Mês formatado | `2024-12` | `YYYY-MM` |
| 📝 **periodo_trimestre** | VARCHAR(7) | ✓ | Ano-Trimestre formatado | `2024-Q4` | `YYYY-Qn` |

**Hierarquia Temporal:**
```
ano -> trimestre -> mes -> dia
ano -> semana_do_ano
```

**Origem:** Gerada pelo script (não vem de sistema fonte)

---


## DIM_CLIENTE - Dimensão Cliente

**Schema:** `dim.DIM_CLIENTE`  
**Registros Estimados:** 10.000 - 1.000.000  
**Crescimento:** Alto (novos clientes diariamente)  
**SCD Type:** Type 1 (sobrescreve)

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **cliente_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **cliente_original_id** | INT | ✓ | Natural Key do sistema de origem | `45123` | UNIQUE |
| 📝 **nome_cliente** | VARCHAR(100) | ✓ | Nome completo ou razão social | `João Silva` | - |
| 📝 **email** | VARCHAR(100) | ✗ | Email principal | `joao@email.com` | - |
| 📝 **telefone** | VARCHAR(20) | ✗ | Telefone | `(11) 98765-4321` | - |
| 📝 **cpf_cnpj** | VARCHAR(18) | ✗ | CPF ou CNPJ | `123.456.789-00` | - |
| 🗓️ **data_nascimento** | DATE | ✗ | Data de nascimento | `1985-03-15` | - |
| 📝 **genero** | CHAR(1) | ✗ | Gênero | `M` | `IN ('M','F','O')` |
| 📝 **tipo_cliente** | VARCHAR(20) | ✓ | Novo, Recorrente, VIP ou Inativo | `Recorrente` | `IN ('Novo','Recorrente','VIP','Inativo')` |
| 📝 **segmento** | VARCHAR(20) | ✓ | Pessoa Física ou Jurídica | `Pessoa Física` | `IN ('Pessoa Física','Pessoa Jurídica')` |
| 📝 **score_credito** | INT | ✗ | Score de crédito | `850` | `>= 0` |
| 📝 **categoria_valor** | VARCHAR(20) | ✗ | Categoria de valor | `Ouro` | `IN ('Bronze','Prata','Ouro','Platinum')` |
| 📝 **endereco_completo** | VARCHAR(200) | ✗ | Logradouro | `Av. Paulista, 1000` | - |
| 📝 **numero** | VARCHAR(10) | ✗ | Número | `1000` | - |
| 📝 **complemento** | VARCHAR(50) | ✗ | Complemento | `Apto 12` | - |
| 📝 **bairro** | VARCHAR(50) | ✗ | Bairro | `Bela Vista` | - |
| 📝 **cidade** | VARCHAR(100) | ✓ | Cidade | `São Paulo` | - |
| 📝 **estado** | CHAR(2) | ✓ | UF | `SP` | `LEN = 2` |
| 📝 **pais** | VARCHAR(50) | ✓ | País | `Brasil` | Default: `Brasil` |
| 📝 **cep** | VARCHAR(10) | ✗ | CEP | `01310-100` | - |
| 🗓️ **data_primeiro_cadastro** | DATE | ✓ | Data do primeiro cadastro | `2020-01-15` | - |
| 🗓️ **data_ultima_compra** | DATE | ✗ | Última compra | `2024-11-28` | - |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última atualização | `2024-12-15 10:00:00` | - |
| 📊 **total_compras_historico** | INT | ✓ | Total de compras históricas | `145` | `>= 0` |
| 📊 **valor_total_gasto_historico** | DECIMAL(12,2) | ✓ | Valor total gasto | `87500.00` | `>= 0` |
| 📊 **ticket_medio_historico** | DECIMAL(10,2) | ✗ | Ticket médio | `603.45` | - |
| 🏷️ **eh_ativo** | BIT | ✓ | Status do cliente | `1` | 1=Ativo, 0=Inativo |
| 🏷️ **aceita_email_marketing** | BIT | ✓ | Opt-in de marketing | `1` | 1=Sim, 0=Não |
| 🏷️ **eh_cliente_vip** | BIT | ✓ | Flag de cliente VIP | `1` | 1=Sim, 0=Não |

**Origem:** Sistema transacional/CRM

**Tipo de Cliente (tipo_cliente):**
- Novo: primeira compra
- Recorrente: 2+ compras
- VIP: alto valor
- Inativo: sem compra recente

**Categoria de Valor (categoria_valor):**
- Bronze: até R$ 1.000
- Prata: R$ 1.000 - R$ 10.000
- Ouro: R$ 10.000 - R$ 50.000
- Platinum: acima de R$ 50.000

---


## DIM_PRODUTO - Dimensão Produto

**Schema:** `dim.DIM_PRODUTO`  
**Registros Estimados:** 1.000 - 100.000  
**Crescimento:** Médio (novos produtos mensalmente)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **produto_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **produto_original_id** | INT | ✓ | Natural Key do ERP | `78945` | UNIQUE |
| 📝 **codigo_sku** | VARCHAR(50) | ✓ | Stock Keeping Unit | `DELL-NB-INS15-001` | UNIQUE |
| 📝 **codigo_barras** | VARCHAR(20) | ✗ | EAN/UPC | `7891234567890` | - |
| 📝 **nome_produto** | VARCHAR(150) | ✓ | Nome do produto | `Notebook Dell Inspiron 15` | - |
| 📝 **descricao_curta** | VARCHAR(255) | ✗ | Descrição curta | `Notebook i5 8GB 256GB` | - |
| 📝 **descricao_completa** | VARCHAR(MAX) | ✗ | Descrição completa | `Detalhes técnicos...` | - |
| 📝 **categoria** | VARCHAR(50) | ✓ | Categoria principal | `Eletrônicos` | - |
| 📝 **subcategoria** | VARCHAR(50) | ✓ | Subcategoria | `Notebooks` | - |
| 📝 **linha_produto** | VARCHAR(50) | ✗ | Linha do produto | `Linha Inspiron` | - |
| 📝 **marca** | VARCHAR(50) | ✓ | Marca | `Dell` | - |
| 📝 **fabricante** | VARCHAR(100) | ✗ | Fabricante | `Dell Inc.` | - |
| 🔗 **fornecedor_id** | INT | ✓ | ID do fornecedor | `101` | - |
| 📝 **nome_fornecedor** | VARCHAR(100) | ✓ | Nome do fornecedor | `Tech Supply` | - |
| 📝 **pais_origem** | VARCHAR(50) | ✗ | País de origem | `Estados Unidos` | - |
| 📊 **peso_kg** | DECIMAL(8,3) | ✗ | Peso em kg | `2.150` | `>= 0` |
| 📝 **altura_cm** | DECIMAL(6,2) | ✗ | Altura em cm | `2.50` | `>= 0` |
| 📝 **largura_cm** | DECIMAL(6,2) | ✗ | Largura em cm | `35.80` | `>= 0` |
| 📝 **profundidade_cm** | DECIMAL(6,2) | ✗ | Profundidade em cm | `24.00` | `>= 0` |
| 📝 **cor_principal** | VARCHAR(30) | ✗ | Cor principal | `Preto` | - |
| 📝 **material** | VARCHAR(50) | ✗ | Material | `Mesh/Borracha` | - |
| 📊 **preco_custo** | DECIMAL(10,2) | ✓ | Custo de aquisição | `2400.00` | `>= 0` |
| 📊 **preco_sugerido** | DECIMAL(10,2) | ✓ | Preço de tabela | `3499.00` | `>= 0` |
| 📊 **margem_sugerida_percent** | DECIMAL(5,2) | ✗ | Margem sugerida (%) | `31.42` | `BETWEEN 0 AND 100` |
| 🏷️ **eh_perecivel** | BIT | ✓ | Produto perecível | `0` | 1=Sim, 0=Não |
| 🏷️ **eh_fragil** | BIT | ✓ | Produto frágil | `1` | 1=Sim, 0=Não |
| 🏷️ **requer_refrigeracao** | BIT | ✓ | Precisa refrigerar | `0` | 1=Sim, 0=Não |
| 📝 **idade_minima_venda** | INT | ✗ | Idade mínima | `18` | - |
| 📊 **estoque_minimo** | INT | ✓ | Estoque mínimo | `5` | `>= 0` |
| 📊 **estoque_maximo** | INT | ✓ | Estoque máximo | `100` | `>= estoque_minimo` |
| 📝 **prazo_reposicao_dias** | INT | ✗ | Prazo de reposição | `15` | - |
| 📝 **situacao** | VARCHAR(20) | ✓ | Status | `Ativo` | `IN ('Ativo','Inativo','Descontinuado')` |
| 🗓️ **data_lancamento** | DATE | ✗ | Data de lançamento | `2023-06-15` | - |
| 🗓️ **data_descontinuacao** | DATE | ✗ | Data de descontinuação | `2018-12-31` | - |
| 🗓️ **data_cadastro** | DATETIME | ✓ | Data de cadastro | `2024-01-01 00:00:00` | - |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última atualização | `2024-12-15 09:00:00` | - |
| 📝 **palavras_chave** | VARCHAR(200) | ✗ | Palavras-chave | `notebook, i5, 8gb` | - |
| 📊 **avaliacao_media** | DECIMAL(2,1) | ✗ | Avaliação média | `4.5` | `BETWEEN 0 AND 5` |
| 📊 **total_avaliacoes** | INT | ✓ | Total de avaliações | `127` | `>= 0` |

**Hierarquia de Categorias:**
```
categoria -> subcategoria -> linha_produto -> produto -> SKU
```

**Origem:** Sistema ERP (SAP/TOTVS)

**Regra de Margem:**
```sql
margem_sugerida_percent = (preco_sugerido - preco_custo) / preco_sugerido * 100
```

---


## DIM_REGIAO - Dimensão Geográfica

**Schema:** `dim.DIM_REGIAO`  
**Registros Estimados:** 100 - 5.000 (municípios brasileiros)  
**Crescimento:** Muito baixo (raramente adiciona cidades)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **regiao_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **regiao_original_id** | INT | ✓ | Natural Key | `3550308` | UNIQUE, código IBGE |
| 📝 **pais** | VARCHAR(50) | ✓ | País | `"Brasil"` | Default: 'Brasil' |
| 📝 **regiao_pais** | VARCHAR(30) | ✗ | Região do país | `"Sudeste"` | `IN ('Norte','Nordeste','Centro-Oeste','Sudeste','Sul')` |
| 📝 **estado** | CHAR(2) | ✓ | Sigla UF | `"SP"` | `LEN = 2` |
| 📝 **nome_estado** | VARCHAR(50) | ✓ | Nome completo do estado | `"São Paulo"` | - |
| 📝 **cidade** | VARCHAR(100) | ✓ | Nome do município | `"São Paulo"` | - |
| 📝 **codigo_ibge** | VARCHAR(10) | ✗ | Código IBGE de 7 dígitos | `"3550308"` | Formato: XXXXXXX |
| 📝 **cep_inicial** | VARCHAR(10) | ✗ | CEP inicial da região | `"01000-000"` | Formato: XXXXX-XXX |
| 📝 **cep_final** | VARCHAR(10) | ✗ | CEP final da região | `"05999-999"` | Formato: XXXXX-XXX |
| 📝 **ddd** | CHAR(2) | ✗ | Código DDD telefônico | `"11"` | `LEN = 2` |
| 📊 **populacao_estimada** | INT | ✗ | População do município | `12325232` | `> 0`, fonte: IBGE |
| 📊 **area_km2** | DECIMAL(10,2) | ✗ | Área em km² | `1521.11` | `> 0` |
| 📊 **densidade_demografica** | DECIMAL(10,2) | ✗ | Habitantes por km² | `8097.99` | Calculado: pop/área |
| 📝 **tipo_municipio** | VARCHAR(30) | ✗ | Classificação | `"Capital"` | `IN ('Capital','Interior','Região Metropolitana')` |
| 📝 **porte_municipio** | VARCHAR(20) | ✗ | Porte por população | `"Grande"` | `IN ('Grande','Médio','Pequeno')` |
| 📊 **pib_per_capita** | DECIMAL(10,2) | ✗ | PIB per capita em R$ | `52796.00` | Fonte: IBGE |
| 📊 **idh** | DECIMAL(4,3) | ✗ | Índice Desenv. Humano | `0.805` | `BETWEEN 0 AND 1` |
| 📊 **latitude** | DECIMAL(10,7) | ✗ | Coordenada geográfica | `-23.5505199` | Formato decimal |
| 📊 **longitude** | DECIMAL(10,7) | ✗ | Coordenada geográfica | `-46.6333094` | Formato decimal |
| 📝 **fuso_horario** | VARCHAR(50) | ✗ | Timezone IANA | `"America/Sao_Paulo"` | - |
| 🗓️ **data_cadastro** | DATETIME | ✓ | Data de criação do registro | `2024-01-01 00:00:00` | Default: GETDATE() |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última modificação | `2024-12-15 10:30:00` | Atualizado em UPDATE |
| 🏷️ **eh_ativo** | BIT | ✓ | Região ativa | `1` | Default: 1 |

**Hierarquia Geográfica:**
```
pais → regiao_pais → estado → cidade
```

**Origem:** Base de dados IBGE + enriquecimento demográfico

**Unique Constraint:**
```sql
UNIQUE (pais, estado, cidade)
```

---

## DIM_EQUIPE - Dimensão Equipe

**Schema:** `dim.DIM_EQUIPE`  
**Registros Estimados:** 10 - 100  
**Crescimento:** Baixo (reorganizações ocasionais)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **equipe_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **equipe_original_id** | INT | ✓ | Natural Key (RH/CRM) | `501` | UNIQUE |
| 📝 **nome_equipe** | VARCHAR(100) | ✓ | Nome da equipe | `"Equipe Alpha SP"` | UNIQUE |
| 📝 **codigo_equipe** | VARCHAR(20) | ✗ | Código interno | `"EQ-SP-01"` | - |
| 📝 **tipo_equipe** | VARCHAR(30) | ✗ | Tipo de atuação | `"Vendas Diretas"` | `IN ('Vendas Diretas','Inside Sales','Key Accounts','Varejo','E-commerce')` |
| 📝 **categoria_equipe** | VARCHAR(30) | ✗ | Classificação performance | `"Elite"` | `IN ('Elite','Avançado','Intermediário','Iniciante')` |
| 📝 **regional** | VARCHAR(50) | ✗ | Região de atuação | `"Sudeste"` | - |
| 📝 **estado_sede** | CHAR(2) | ✗ | UF da sede | `"SP"` | `LEN = 2` |
| 📝 **cidade_sede** | VARCHAR(100) | ✗ | Cidade da sede | `"São Paulo"` | - |
| 🔗 **lider_equipe_id** | INT | ✗ | FK → DIM_VENDEDOR | `1` | Circular reference |
| 📝 **nome_lider** | VARCHAR(150) | ✗ | Nome do líder (desnorm.) | `"Carlos Silva"` | Atualizado com ETL |
| 📝 **email_lider** | VARCHAR(255) | ✗ | Email do líder | `"carlos@empresa.com"` | - |
| 📊 **meta_mensal_equipe** | DECIMAL(15,2) | ✗ | Meta de vendas mensal | `500000.00` | `>= 0` |
| 📊 **meta_trimestral_equipe** | DECIMAL(15,2) | ✗ | Meta trimestral | `1500000.00` | Geralmente meta_mensal * 3 |
| 📊 **meta_anual_equipe** | DECIMAL(15,2) | ✗ | Meta anual | `6000000.00` | - |
| 📊 **qtd_meta_vendas_mes** | INT | ✗ | Meta de quantidade mensal | `150` | Número de transações |
| 📊 **qtd_membros_atual** | INT | ✗ | Vendedores atuais | `8` | Atualizado por ETL |
| 📊 **qtd_membros_ideal** | INT | ✗ | Tamanho ideal da equipe | `10` | Planejamento RH |
| 📊 **total_vendas_mes_anterior** | DECIMAL(15,2) | ✗ | Vendas do último mês | `520000.00` | Snapshot |
| 📊 **percentual_meta_mes_anterior** | DECIMAL(5,2) | ✗ | % meta atingida | `104.00` | Calculado |
| 📊 **ranking_ultimo_mes** | INT | ✗ | Posição no ranking | `2` | 1 = melhor equipe |
| 🗓️ **data_criacao** | DATE | ✓ | Data de formação | `2023-01-15` | - |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última modificação | `2024-12-15 10:00:00` | Default: GETDATE() |
| 🗓️ **data_inativacao** | DATE | ✗ | Data de desativação | `NULL` | NULL se ativa |
| 📝 **situacao** | VARCHAR(20) | ✓ | Status da equipe | `"Ativa"` | `IN ('Ativa','Inativa','Suspensa','Em Formação')` |
| 🏷️ **eh_ativa** | BIT | ✓ | Flag booleana | `1` | Default: 1 |
| 📝 **observacoes** | VARCHAR(500) | ✗ | Notas | `"Especializada em B2B"` | Texto livre |

**Origem:** Sistema RH + CRM

**Relacionamento Circular:**
- `DIM_EQUIPE.lider_equipe_id` → `DIM_VENDEDOR.vendedor_id`
- `DIM_VENDEDOR.equipe_id` → `DIM_EQUIPE.equipe_id`

**Solução:** Criar DIM_EQUIPE primeiro, popular DIM_VENDEDOR, depois atualizar líderes

---

## DIM_VENDEDOR - Dimensão Vendedor

**Schema:** `dim.DIM_VENDEDOR`  
**Registros Estimados:** 50 - 1.000  
**Crescimento:** Médio (contratações e desligamentos)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **vendedor_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **vendedor_original_id** | INT | ✓ | Natural Key (RH) | `10234` | UNIQUE |
| 📝 **nome_vendedor** | VARCHAR(150) | ✓ | Nome completo | `"João da Silva"` | - |
| 📝 **nome_exibicao** | VARCHAR(50) | ✗ | Nome curto | `"João S."` | Para dashboards |
| 📝 **matricula** | VARCHAR(20) | ✗ | Matrícula funcional | `"VND2024001"` | UNIQUE |
| 📝 **cpf** | VARCHAR(14) | ✗ | CPF do vendedor | `"123.456.789-00"` | UNIQUE, formato com pontuação |
| 📝 **email** | VARCHAR(255) | ✓ | Email corporativo | `"joao.silva@empresa.com"` | UNIQUE |
| 📝 **email_pessoal** | VARCHAR(255) | ✗ | Email pessoal | `"joao@gmail.com"` | Backup |
| 📝 **telefone_celular** | VARCHAR(20) | ✗ | Telefone móvel | `"(11) 99999-9999"` | - |
| 📝 **telefone_comercial** | VARCHAR(20) | ✗ | Ramal | `"(11) 3333-4444 R:123"` | - |
| 📝 **cargo** | VARCHAR(50) | ✓ | Cargo atual | `"Vendedor Pleno"` | - |
| 📝 **nivel_senioridade** | VARCHAR(20) | ✗ | Nível | `"Pleno"` | `IN ('Júnior','Pleno','Sênior','Especialista','Gerente')` |
| 📝 **departamento** | VARCHAR(50) | ✗ | Departamento | `"Vendas"` | - |
| 📝 **area** | VARCHAR(50) | ✗ | Área específica | `"B2B"` | - |
| 🔗 **equipe_id** | INT | ✗ | FK → DIM_EQUIPE | `1` | NULL = sem equipe |
| 📝 **nome_equipe** | VARCHAR(100) | ✗ | Nome da equipe (desnorm.) | `"Equipe Alpha SP"` | - |
| 🔗 **gerente_id** | INT | ✗ | FK → DIM_VENDEDOR (self) | `5` | NULL = sem gerente |
| 📝 **nome_gerente** | VARCHAR(150) | ✗ | Nome do gerente (desnorm.) | `"Carlos Silva"` | - |
| 📝 **estado_atuacao** | CHAR(2) | ✗ | UF principal | `"SP"` | - |
| 📝 **cidade_atuacao** | VARCHAR(100) | ✗ | Cidade base | `"São Paulo"` | - |
| 📝 **territorio_vendas** | VARCHAR(100) | ✗ | Território | `"Grande SP"` | - |
| 📝 **tipo_vendedor** | VARCHAR(30) | ✗ | Tipo de atuação | `"Externo"` | `IN ('Interno','Externo','Híbrido','Remoto')` |
| 📊 **meta_mensal_base** | DECIMAL(15,2) | ✗ | Meta padrão mensal | `50000.00` | Base para FACT_METAS |
| 📊 **meta_trimestral_base** | DECIMAL(15,2) | ✗ | Meta trimestral | `150000.00` | - |
| 📊 **percentual_comissao_padrao** | DECIMAL(5,2) | ✗ | % comissão | `3.50` | `BETWEEN 0 AND 100` |
| 📝 **tipo_comissao** | VARCHAR(30) | ✗ | Tipo | `"Variável"` | `IN ('Fixa','Variável','Escalonada')` |
| 📊 **total_vendas_mes_atual** | DECIMAL(15,2) | ✗ | Vendas do mês corrente | `45000.00` | Snapshot, atualizado |
| 📊 **total_vendas_mes_anterior** | DECIMAL(15,2) | ✗ | Vendas do mês passado | `52000.00` | Snapshot |
| 📊 **percentual_meta_mes_anterior** | DECIMAL(5,2) | ✗ | % meta atingida | `104.00` | - |
| 📊 **ranking_mes_anterior** | INT | ✗ | Posição no ranking | `3` | 1 = melhor |
| 📊 **total_vendas_acumulado_ano** | DECIMAL(15,2) | ✗ | Total no ano | `600000.00` | Year-to-date |
| 🗓️ **data_contratacao** | DATE | ✓ | Data de admissão | `2023-01-15` | - |
| 🗓️ **data_primeira_venda** | DATE | ✗ | Primeira transação | `2023-02-01` | Marco |
| 🗓️ **data_ultima_venda** | DATE | ✗ | Última transação | `2024-12-14` | Atualizado |
| 🗓️ **data_desligamento** | DATE | ✗ | Data de saída | `NULL` | NULL = ativo |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última modificação | `2024-12-15 09:00:00` | - |
| 📝 **situacao** | VARCHAR(20) | ✓ | Status | `"Ativo"` | `IN ('Ativo','Afastado','Suspenso','Desligado')` |
| 🏷️ **eh_ativo** | BIT | ✓ | Flag booleana | `1` | Default: 1 |
| 🏷️ **eh_lider** | BIT | ✓ | É líder de equipe? | `0` | 0=Não, 1=Sim |
| 🏷️ **aceita_novos_clientes** | BIT | ✓ | Aceita leads? | `1` | Controle de distribuição |
| 📝 **observacoes** | VARCHAR(500) | ✗ | Notas | `"Especialista B2B"` | - |
| 📝 **motivo_desligamento** | VARCHAR(200) | ✗ | Motivo | `"Pedido de demissão"` | Se desligado |

**Origem:** Sistema RH (ADP/Workday)

**Self-Join Hierarchy:**
```sql
-- Exemplo de hierarquia
vendedor.gerente_id → vendedor.vendedor_id
```

---

## DIM_DESCONTO - Dimensão Desconto

**Schema:** `dim.DIM_DESCONTO`  
**Registros Estimados:** 100 - 1.000  
**Crescimento:** Médio (novas campanhas)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **desconto_id** | INT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **desconto_original_id** | INT | ✓ | Natural Key (Marketing) | `7890` | UNIQUE |
| 📝 **codigo_desconto** | VARCHAR(50) | ✓ | Código do cupom | `"BLACKFRIDAY"` | UNIQUE |
| 📝 **nome_campanha** | VARCHAR(100) | ✓ | Nome da campanha | `"Black Friday 2024"` | - |
| 📝 **tipo_desconto** | VARCHAR(30) | ✓ | Tipo de desconto | `"Percentual"` | `IN ('Percentual','Valor Fixo','Frete Grátis','Brinde')` |
| 📝 **metodo_desconto** | VARCHAR(30) | ✓ | Método de aplicação | `"Cupom"` | `IN ('Cupom','Automático','Negociado','Volume')` |
| 📊 **valor_desconto** | DECIMAL(10,2) | ✓ | Valor (R$ ou %) | `10.00` | `> 0`, interpretação depende do tipo |
| 📊 **min_valor_compra_regra** | DECIMAL(10,2) | ✗ | Valor mínimo para aplicar | `100.00` | NULL = sem mínimo |
| 📊 **max_valor_desconto_regra** | DECIMAL(10,2) | ✗ | Teto do desconto | `50.00` | NULL = sem teto |
| 📝 **aplica_em** | VARCHAR(30) | ✓ | Nível de aplicação | `"Carrinho"` | `IN ('Produto','Categoria','Carrinho','Frete')` |
| 🗓️ **data_inicio_validade** | DATE | ✓ | Início da vigência | `2024-11-25` | - |
| 🗓️ **data_fim_validade** | DATE | ✗ | Fim da vigência | `2024-11-30` | NULL = sem expiração |
| 📝 **situacao** | VARCHAR(20) | ✓ | Status | `"Ativo"` | `IN ('Ativo','Inativo','Expirado','Pausado')` |

**Origem:** Sistema de Marketing/Promoções

**Vigência:**
```sql
-- Cupom está vigente se:
GETDATE() BETWEEN data_inicio_validade AND ISNULL(data_fim_validade, '9999-12-31')
AND situacao = 'Ativo'
```

---

## 📊 TABELAS FATO

## FACT_VENDAS - Fato Transacional

**Schema:** `fact.FACT_VENDAS`  
**Registros Estimados:** Milhões (cresce continuamente)  
**Crescimento:** Alto (centenas/milhares por dia)  
**Tipo:** Transaction Fact Table

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **venda_id** | BIGINT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **data_id** | INT | ✓ | FK → DIM_DATA | `20241215` | NOT NULL |
| 🔗 **cliente_id** | INT | ✓ | FK → DIM_CLIENTE | `5` | NOT NULL |
| 🔗 **produto_id** | INT | ✓ | FK → DIM_PRODUTO | `10` | NOT NULL |
| 🔗 **regiao_id** | INT | ✓ | FK → DIM_REGIAO | `1` | NOT NULL |
| 🔗 **vendedor_id** | INT | ✗ | FK → DIM_VENDEDOR | `3` | NULL = venda direta |
| 📊 **quantidade_vendida** | INT | ✓ | Unidades vendidas | `2` | `> 0` |
| 📊 **preco_unitario_tabela** | DECIMAL(10,2) | ✓ | Preço de tabela | `3500.00` | `> 0` |
| 📊 **valor_total_bruto** | DECIMAL(15,2) | ✓ | Valor antes de descontos | `7000.00` | `>= 0` |
| 📊 **valor_total_descontos** | DECIMAL(15,2) | ✓ | Total de descontos | `700.00` | `>= 0` |
| 📊 **valor_total_liquido** | DECIMAL(15,2) | ✓ | Valor pago pelo cliente | `6300.00` | `>= 0` |
| 📊 **custo_total** | DECIMAL(15,2) | ✓ | Custo dos produtos | `4000.00` | `>= 0` |
| 📊 **quantidade_devolvida** | INT | ✓ | Unidades devolvidas | `0` | `>= 0`, `<= quantidade_vendida` |
| 📊 **valor_devolvido** | DECIMAL(15,2) | ✓ | Valor reembolsado | `0.00` | `>= 0` |
| 📊 **percentual_comissao** | DECIMAL(5,2) | ✗ | % comissão vendedor | `3.50` | `BETWEEN 0 AND 100` |
| 📊 **valor_comissao** | DECIMAL(15,2) | ✗ | Valor da comissão | `220.50` | `>= 0` |
| 📝 **numero_pedido** | VARCHAR(20) | ✓ | Número do pedido (DD) | `"PED-2024-123456"` | Degenerate Dimension |
| 🏷️ **teve_desconto** | BIT | ✓ | Flag de desconto | `1` | 0=Não, 1=Sim |
| 🗓️ **data_inclusao** | DATETIME | ✓ | Quando foi inserido | `2024-12-15 10:30:00` | Default: GETDATE() |
| 🗓️ **data_atualizacao** | DATETIME | ✓ | Última atualização | `2024-12-15 10:30:00` | Default: GETDATE() |

**Granularidade:** 1 item vendido em 1 pedido

**Constraints Críticos:**
```sql
-- Valor líquido = bruto - descontos
CHECK (valor_total_liquido = valor_total_bruto - valor_total_descontos)

-- Quantidade devolvida <= vendida
CHECK (quantidade_devolvida <= quantidade_vendida)
```

**Métricas Calculadas (em queries):**
```sql
-- Margem
(valor_total_liquido - custo_total) AS lucro_bruto
(valor_total_liquido - custo_total) / valor_total_liquido * 100 AS margem_percentual

-- Ticket médio
AVG(valor_total_liquido) AS ticket_medio
```

---

## FACT_METAS - Snapshot Periódico

**Schema:** `fact.FACT_METAS`  
**Registros Estimados:** Milhares (controlado)  
**Crescimento:** Baixo (número vendedores × períodos)  
**Tipo:** Periodic Snapshot Fact Table

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **meta_id** | BIGINT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **vendedor_id** | INT | ✓ | FK → DIM_VENDEDOR | `3` | NOT NULL |
| 🔗 **data_id** | INT | ✓ | FK → DIM_DATA | `20241201` | NOT NULL (1º dia do mês) |
| 📊 **valor_meta** | DECIMAL(15,2) | ✓ | Meta em R$ | `50000.00` | `> 0` |
| 📊 **quantidade_meta** | INT | ✗ | Meta em quantidade | `20` | `> 0` |
| 📊 **valor_realizado** | DECIMAL(15,2) | ✓ | Vendas reais | `52500.00` | `>= 0` |
| 📊 **quantidade_realizada** | INT | ✓ | Vendas reais (qtd) | `22` | `>= 0` |
| 📊 **percentual_atingido** | DECIMAL(5,2) | ✓ | % da meta | `105.00` | `>= 0` |
| 📊 **gap_meta** | DECIMAL(15,2) | ✓ | Diferença | `2500.00` | Pode ser negativo |
| 📊 **ticket_medio_realizado** | DECIMAL(10,2) | ✗ | Ticket médio | `2386.36` | Calculado |
| 📊 **ranking_periodo** | INT | ✗ | Posição no ranking | `3` | 1 = melhor |
| 📝 **quartil_performance** | VARCHAR(10) | ✗ | Quartil | `"Q1"` | `IN ('Q1','Q2','Q3','Q4')` |
| 🏷️ **meta_batida** | BIT | ✓ | Atingiu meta? | `1` | 0=Não, 1=Sim |
| 🏷️ **meta_superada** | BIT | ✓ | Superou meta? | `1` | 0=Não, 1=Sim (>100%) |
| 🏷️ **eh_periodo_fechado** | BIT | ✓ | Período encerrado? | `1` | 0=Em andamento, 1=Fechado |
| 📝 **tipo_periodo** | VARCHAR(20) | ✓ | Tipo | `"Mensal"` | `IN ('Mensal','Trimestral','Anual')` |
| 📝 **observacoes** | VARCHAR(500) | ✗ | Notas | `"Meta ajustada devido férias"` | - |
| 🗓️ **data_inclusao** | DATETIME | ✓ | Quando criado | `2024-12-01 00:00:00` | Default: GETDATE() |
| 🗓️ **data_ultima_atualizacao** | DATETIME | ✓ | Última atualização | `2024-12-31 23:59:59` | Atualizado no ETL |

**Granularidade:** 1 meta de 1 vendedor em 1 período

**Unique Constraint:**
```sql
UNIQUE (vendedor_id, data_id, tipo_periodo)
-- Garante: vendedor não pode ter 2 metas no mesmo período
```

**Constraint de Coerência:**
```sql
CHECK (
    (meta_batida = 0 AND percentual_atingido < 100) OR
    (meta_batida = 1 AND percentual_atingido >= 100)
)
```

---

## FACT_DESCONTOS - Fato Transacional

**Schema:** `fact.FACT_DESCONTOS`  
**Registros Estimados:** Variável (depende de campanhas)  
**Crescimento:** Médio (múltiplos descontos por venda)  
**Tipo:** Transaction Fact Table

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **desconto_aplicado_id** | BIGINT | ✓ | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| 🔗 **desconto_id** | INT | ✓ | FK → DIM_DESCONTO | `10` | NOT NULL |
| 🔗 **venda_id** | BIGINT | ✓ | FK → FACT_VENDAS | `123` | NOT NULL |
| 🔗 **data_aplicacao_id** | INT | ✓ | FK → DIM_DATA | `20241215` | NOT NULL |
| 🔗 **cliente_id** | INT | ✓ | FK → DIM_CLIENTE | `5` | NOT NULL (desnorm.) |
| 🔗 **produto_id** | INT | ✗ | FK → DIM_PRODUTO | `10` | NULL se desconto no pedido |
| 📝 **nivel_aplicacao** | VARCHAR(20) | ✓ | Nível | `"Produto"` | `IN ('Produto','Pedido','Frete')` |
| 📊 **valor_desconto_aplicado** | DECIMAL(10,2) | ✓ | Valor do desconto | `350.00` | `>= 0` |
| 📊 **valor_sem_desconto** | DECIMAL(10,2) | ✓ | Valor original | `3500.00` | `>= 0` |
| 📊 **valor_com_desconto** | DECIMAL(10,2) | ✓ | Valor final | `3150.00` | `>= 0` |
| 📊 **margem_antes_desconto** | DECIMAL(10,2) | ✓ | Margem original | `1500.00` | Pode ser negativo |
| 📊 **margem_apos_desconto** | DECIMAL(10,2) | ✓ | Margem final | `1150.00` | Pode ser negativo |
| 📊 **impacto_margem** | DECIMAL(10,2) | ✓ | Redução | `-350.00` | Negativo = perda |
| 📝 **numero_pedido** | VARCHAR(20) | ✓ | Número do pedido (DD) | `"PED-2024-123456"` | Degenerate Dimension |
| 🏷️ **desconto_aprovado** | BIT | ✓ | Foi aprovado? | `1` | 0=Não, 1=Sim |
| 🗓️ **data_inclusao** | DATETIME | ✓ | Quando registrado | `2024-12-15 10:30:00` | Default: GETDATE() |

**Granularidade:** 1 desconto aplicado em 1 venda

**Relacionamento Fact-to-Fact:**
```sql
-- Um pedido pode ter múltiplos descontos
-- Exemplo: cupom + volume + frete grátis
```

**Constraints:**
```sql
-- Valor com desconto = sem desconto - desconto aplicado
CHECK (valor_com_desconto = valor_sem_desconto - valor_desconto_aplicado)
```

---

## 🔍 VIEWS AUXILIARES

### Views Dimensionais

| View | Descrição | Base |
|------|-----------|------|
| **VW_CALENDARIO_COMPLETO** | Calendário + campos calculados | DIM_DATA |
| **VW_PRODUTOS_ATIVOS** | Produtos ativos + margem | DIM_PRODUTO |
| **VW_HIERARQUIA_GEOGRAFICA** | Hierarquia geográfica | DIM_REGIAO |
| **VW_DESCONTOS_ATIVOS** | Descontos vigentes | DIM_DESCONTO |
| **VW_VENDEDORES_ATIVOS** | Vendedores + tempo casa | DIM_VENDEDOR |
| **VW_HIERARQUIA_VENDEDORES** | Hierarquia gerencial | DIM_VENDEDOR (self-join) |

### Views de Equipes

| View | Descrição | Base |
|------|-----------|------|
| **VW_ANALISE_EQUIPE_VENDEDORES** | Análise de composição | DIM_EQUIPE + DIM_VENDEDOR |
| **VW_EQUIPES_ATIVAS** | Equipes operacionais | DIM_EQUIPE |
| **VW_RANKING_EQUIPES_META** | Ranking por meta | DIM_EQUIPE |
| **VW_ANALISE_REGIONAL_EQUIPES** | Agregação regional | DIM_EQUIPE |

### Views Mestres

| View | Descrição | Base |
|------|-----------|------|
| **VW_VENDAS_COMPLETA** | Vendas + todas dimensões | FACT_VENDAS + JOINs |
| **VW_METAS_COMPLETA** | Metas + contexto completo | FACT_METAS + JOINs |

**Documentação completa:** Ver `sql/04_views/README.md`

---

## 📚 Glossário de Termos

### Termos de Modelagem Dimensional

| Termo | Definição |
|-------|-----------|
| **Star Schema** | Modelo com fact no centro e dimensions ao redor (estrela) |
| **Snowflake Schema** | Star schema com dimensões normalizadas |
| **Surrogate Key** | Chave artificial (1,2,3...) gerada pelo DW |
| **Natural Key** | Chave do sistema fonte (codigo_sku, cpf) |
| **Granularidade** | Nível de detalhe: o que é 1 linha da fact? |
| **SCD Type 1** | Sobrescreve: valor antigo perdido |
| **SCD Type 2** | Novo registro: histórico completo mantido |
| **Degenerate Dimension (DD)** | Atributo descritivo que fica na fact (numero_pedido) |
| **Conformed Dimension** | Dimensão compartilhada entre múltiplas facts |

### Tipos de Métricas

| Termo | Definição |
|-------|-----------|
| **Additive Measure** | Métrica somável em todas dimensões (quantidade) |
| **Semi-Additive** | Somável em algumas dimensões (saldo_conta) |
| **Non-Additive** | Não somável, deve ser calculada (percentual) |

### Operações Analíticas

| Termo | Definição |
|-------|-----------|
| **Drill-Down** | Detalhar: ano → trimestre → mês |
| **Roll-Up** | Agregar: dia → mês → ano |
| **Slice** | Filtrar uma dimensão: "apenas 2024" |
| **Dice** | Filtrar múltiplas dimensões: "2024 + SP + Eletrônicos" |

### Tipos de Facts

| Termo | Definição |
|-------|-----------|
| **Transaction Fact** | Cada linha = evento individual (FACT_VENDAS) |
| **Periodic Snapshot** | Foto periódica do estado (FACT_METAS) |
| **Accumulating Snapshot** | Processo com múltiplas etapas (não implementado) |

---

## 📊 Resumo Estatístico

### Contagem de Campos por Tabela

| Tabela | Total Campos | PKs | FKs | Métricas | Descritivos | Flags | Temporais |
|--------|--------------|-----|-----|----------|-------------|-------|-----------|
| DIM_DATA | 13 | 1 | 0 | 0 | 10 | 2 | 0 |
| DIM_CLIENTE | 12 | 1 | 1 | 0 | 7 | 1 | 2 |
| DIM_PRODUTO | 14 | 1 | 2 | 3 | 7 | 1 | 0 |
| DIM_REGIAO | 21 | 1 | 1 | 5 | 11 | 1 | 2 |
| DIM_EQUIPE | 22 | 1 | 1 | 9 | 8 | 1 | 3 |
| DIM_VENDEDOR | 38 | 1 | 3 | 7 | 19 | 3 | 5 |
| DIM_DESCONTO | 12 | 1 | 1 | 3 | 5 | 0 | 2 |
| FACT_VENDAS | 18 | 1 | 5 | 9 | 1 | 1 | 2 |
| FACT_METAS | 19 | 1 | 2 | 9 | 2 | 3 | 2 |
| FACT_DESCONTOS | 16 | 1 | 5 | 6 | 2 | 1 | 1 |
| **TOTAL** | **185** | **10** | **21** | **51** | **72** | **14** | **19** |

### Tipos de Dados Mais Usados

| Tipo | Frequência | Uso Principal |
|------|------------|---------------|
| VARCHAR | 42% | Textos descritivos |
| DECIMAL | 18% | Valores monetários e percentuais |
| INT | 15% | IDs e contadores |
| BIT | 8% | Flags booleanas |
| DATE/DATETIME | 10% | Campos temporais |
| BIGINT | 2% | PKs de facts |
| CHAR | 5% | Códigos fixos (UF, DDD) |

---

## 🔍 Índice Alfabético de Campos

<details>
<summary>Clique para expandir lista completa (185 campos)</summary>

### A
- **aceita_novos_clientes** - DIM_VENDEDOR (BIT)
- **ano** - DIM_DATA (INT)
- **aplica_em** - DIM_DESCONTO (VARCHAR)
- **area** - DIM_VENDEDOR (VARCHAR)
- **area_km2** - DIM_REGIAO (DECIMAL)

### C
- **cargo** - DIM_VENDEDOR (VARCHAR)
- **categoria** - DIM_PRODUTO (VARCHAR)
- **categoria_equipe** - DIM_EQUIPE (VARCHAR)
- **cep_final** - DIM_REGIAO (VARCHAR)
- **cep_inicial** - DIM_REGIAO (VARCHAR)
- **cidade** - DIM_CLIENTE, DIM_REGIAO (VARCHAR)
- **cidade_atuacao** - DIM_VENDEDOR (VARCHAR)
- **cidade_sede** - DIM_EQUIPE (VARCHAR)
- **cliente_id** - DIM_CLIENTE (PK), FACT_VENDAS, FACT_DESCONTOS (FK)
- **cliente_original_id** - DIM_CLIENTE (INT)
- **codigo_desconto** - DIM_DESCONTO (VARCHAR)
- **codigo_equipe** - DIM_EQUIPE (VARCHAR)
- **codigo_ibge** - DIM_REGIAO (VARCHAR)
- **codigo_sku** - DIM_PRODUTO (VARCHAR)
- **cpf** - DIM_VENDEDOR (VARCHAR)
- **custo_medio** - DIM_PRODUTO (DECIMAL)
- **custo_total** - FACT_VENDAS (DECIMAL)

### D
- **data_aplicacao_id** - FACT_DESCONTOS (FK)
- **data_cadastro** - DIM_CLIENTE, DIM_REGIAO (DATE)
- **data_completa** - DIM_DATA (DATE)
- **data_contratacao** - DIM_VENDEDOR (DATE)
- **data_criacao** - DIM_EQUIPE, DIM_DESCONTO (DATE/DATETIME)
- **data_desligamento** - DIM_VENDEDOR (DATE)
- **data_fim_validade** - DIM_DESCONTO (DATE)
- **data_id** - DIM_DATA (PK), FACT_VENDAS, FACT_METAS (FK)
- **data_inativacao** - DIM_EQUIPE (DATE)
- **data_inclusao** - FACT_VENDAS, FACT_METAS, FACT_DESCONTOS (DATETIME)
- **data_inicio_validade** - DIM_DESCONTO (DATE)
- **data_primeira_venda** - DIM_VENDEDOR (DATE)
- **data_ultima_atualizacao** - DIM_REGIAO, DIM_EQUIPE, DIM_VENDEDOR, FACT_METAS (DATETIME)
- **data_ultima_compra** - DIM_CLIENTE (DATE)
- **data_ultima_venda** - DIM_VENDEDOR (DATE)
- **ddd** - DIM_REGIAO (CHAR)
- **densidade_demografica** - DIM_REGIAO (DECIMAL)
- **departamento** - DIM_VENDEDOR (VARCHAR)
- **desconto_aplicado_id** - FACT_DESCONTOS (PK)
- **desconto_aprovado** - FACT_DESCONTOS (BIT)
- **desconto_id** - DIM_DESCONTO (PK), FACT_DESCONTOS (FK)
- **desconto_original_id** - DIM_DESCONTO (INT)
- **dia_ano** - DIM_DATA (INT)
- **dia_mes** - DIM_DATA (INT)
- **dia_semana** - DIM_DATA (INT)
- **dimensoes** - DIM_PRODUTO (VARCHAR)

### E
- **eh_ativo** - DIM_CLIENTE, DIM_PRODUTO, DIM_REGIAO, DIM_EQUIPE, DIM_VENDEDOR (BIT)
- **eh_ativa** - DIM_EQUIPE (BIT)
- **eh_feriado** - DIM_DATA (BIT)
- **eh_fim_de_semana** - DIM_DATA (BIT)
- **eh_lider** - DIM_VENDEDOR (BIT)
- **eh_periodo_fechado** - FACT_METAS (BIT)
- **email** - DIM_CLIENTE, DIM_VENDEDOR (VARCHAR)
- **email_lider** - DIM_EQUIPE (VARCHAR)
- **email_pessoal** - DIM_VENDEDOR (VARCHAR)
- **equipe_id** - DIM_EQUIPE (PK), DIM_VENDEDOR (FK)
- **equipe_original_id** - DIM_EQUIPE (INT)
- **estado** - DIM_CLIENTE, DIM_REGIAO (CHAR/VARCHAR)
- **estado_atuacao** - DIM_VENDEDOR (CHAR)
- **estado_sede** - DIM_EQUIPE (CHAR)

### F
- **fornecedor_id** - DIM_PRODUTO (INT)
- **fuso_horario** - DIM_REGIAO (VARCHAR)

### G
- **gap_meta** - FACT_METAS (DECIMAL)
- **gerente_id** - DIM_VENDEDOR (FK self-join)

### I
- **idh** - DIM_REGIAO (DECIMAL)
- **impacto_margem** - FACT_DESCONTOS (DECIMAL)

### L
- **latitude** - DIM_REGIAO (DECIMAL)
- **lider_equipe_id** - DIM_EQUIPE (FK)
- **longitude** - DIM_REGIAO (DECIMAL)

### M
- **mês** - DIM_DATA (INT)
- **marca** - DIM_PRODUTO (VARCHAR)
- **margem_antes_desconto** - FACT_DESCONTOS (DECIMAL)
- **margem_apos_desconto** - FACT_DESCONTOS (DECIMAL)
- **matricula** - DIM_VENDEDOR (VARCHAR)
- **max_valor_desconto_regra** - DIM_DESCONTO (DECIMAL)
- **meta_anual_equipe** - DIM_EQUIPE (DECIMAL)
- **meta_batida** - FACT_METAS (BIT)
- **meta_id** - FACT_METAS (PK)
- **meta_mensal_base** - DIM_VENDEDOR (DECIMAL)
- **meta_mensal_equipe** - DIM_EQUIPE (DECIMAL)
- **meta_superada** - FACT_METAS (BIT)
- **meta_trimestral_base** - DIM_VENDEDOR (DECIMAL)
- **meta_trimestral_equipe** - DIM_EQUIPE (DECIMAL)
- **metodo_desconto** - DIM_DESCONTO (VARCHAR)
- **min_valor_compra_regra** - DIM_DESCONTO (DECIMAL)
- **motivo_desligamento** - DIM_VENDEDOR (VARCHAR)

### N
- **nivel_aplicacao** - FACT_DESCONTOS (VARCHAR)
- **nivel_senioridade** - DIM_VENDEDOR (VARCHAR)
- **nome_cliente** - DIM_CLIENTE (VARCHAR)
- **nome_campanha** - DIM_DESCONTO (VARCHAR)
- **nome_dia_semana** - DIM_DATA (VARCHAR)
- **nome_equipe** - DIM_EQUIPE, DIM_VENDEDOR (VARCHAR)
- **nome_estado** - DIM_REGIAO (VARCHAR)
- **nome_exibicao** - DIM_VENDEDOR (VARCHAR)
- **nome_feriado** - DIM_DATA (VARCHAR)
- **nome_fornecedor** - DIM_PRODUTO (VARCHAR)
- **nome_gerente** - DIM_VENDEDOR (VARCHAR)
- **nome_lider** - DIM_EQUIPE (VARCHAR)
- **nome_mes** - DIM_DATA (VARCHAR)
- **nome_produto** - DIM_PRODUTO (VARCHAR)
- **nome_vendedor** - DIM_VENDEDOR (VARCHAR)
- **numero_pedido** - FACT_VENDAS, FACT_DESCONTOS (VARCHAR)

### O
- **observacoes** - DIM_EQUIPE, DIM_VENDEDOR, DIM_DESCONTO, FACT_METAS (VARCHAR)
DIM_DESCONTO, FACT_METAS (VARCHAR)

### P
- **pais** - DIM_CLIENTE, DIM_REGIAO (VARCHAR)
- **percentual_atingido** - FACT_METAS (DECIMAL)
- **percentual_comissao** - FACT_VENDAS (DECIMAL)
- **percentual_comissao_padrao** - DIM_VENDEDOR (DECIMAL)
- **percentual_meta_mes_anterior** - DIM_EQUIPE, DIM_VENDEDOR (DECIMAL)
- **peso_kg** - DIM_PRODUTO (DECIMAL)
- **pib_per_capita** - DIM_REGIAO (DECIMAL)
- **populacao_estimada** - DIM_REGIAO (INT)
- **porte_municipio** - DIM_REGIAO (VARCHAR)
- **preco_sugerido** - DIM_PRODUTO (DECIMAL)
- **preco_unitario_tabela** - FACT_VENDAS (DECIMAL)
- **produto_id** - DIM_PRODUTO (PK), FACT_VENDAS, FACT_DESCONTOS (FK)
- **produto_original_id** - DIM_PRODUTO (INT)

### Q
- **qtd_membros_atual** - DIM_EQUIPE (INT)
- **qtd_membros_ideal** - DIM_EQUIPE (INT)
- **qtd_meta_vendas_mes** - DIM_EQUIPE (INT)
- **quantidade_devolvida** - FACT_VENDAS (INT)
- **quantidade_meta** - FACT_METAS (INT)
- **quantidade_realizada** - FACT_METAS (INT)
- **quantidade_vendida** - FACT_VENDAS (INT)
- **quartil_performance** - FACT_METAS (VARCHAR)

### R
- **ranking_periodo** - FACT_METAS (INT)
- **ranking_ultimo_mes** - DIM_EQUIPE (INT)
- **ranking_mes_anterior** - DIM_VENDEDOR (INT)
- **regiao_id** - DIM_REGIAO (PK), FACT_VENDAS (FK)
- **regiao_original_id** - DIM_REGIAO (INT)
- **regiao_pais** - DIM_REGIAO (VARCHAR)
- **regional** - DIM_EQUIPE (VARCHAR)

### S
- **segmento** - DIM_CLIENTE (VARCHAR)
- **situacao** - DIM_EQUIPE, DIM_VENDEDOR, DIM_DESCONTO (VARCHAR)
- **subcategoria** - DIM_PRODUTO (VARCHAR)

### T
- **telefone_celular** - DIM_VENDEDOR (VARCHAR)
- **telefone_comercial** - DIM_VENDEDOR (VARCHAR)
- **territorio_vendas** - DIM_VENDEDOR (VARCHAR)
- **teve_desconto** - FACT_VENDAS (BIT)
- **ticket_medio_realizado** - FACT_METAS (DECIMAL)
- **tipo_cliente** - DIM_CLIENTE (VARCHAR)
- **tipo_comissao** - DIM_VENDEDOR (VARCHAR)
- **tipo_desconto** - DIM_DESCONTO (VARCHAR)
- **tipo_equipe** - DIM_EQUIPE (VARCHAR)
- **tipo_municipio** - DIM_REGIAO (VARCHAR)
- **tipo_periodo** - FACT_METAS (VARCHAR)
- **tipo_vendedor** - DIM_VENDEDOR (VARCHAR)
- **total_vendas_acumulado_ano** - DIM_VENDEDOR (DECIMAL)
- **total_vendas_mes_anterior** - DIM_EQUIPE, DIM_VENDEDOR (DECIMAL)
- **total_vendas_mes_atual** - DIM_VENDEDOR (DECIMAL)
- **trimestre** - DIM_DATA (INT)

### V
- **valor_comissao** - FACT_VENDAS (DECIMAL)
- **valor_com_desconto** - FACT_DESCONTOS (DECIMAL)
- **valor_desconto** - DIM_DESCONTO (DECIMAL)
- **valor_desconto_aplicado** - FACT_DESCONTOS (DECIMAL)
- **valor_devolvido** - FACT_VENDAS (DECIMAL)
- **valor_meta** - FACT_METAS (DECIMAL)
- **valor_realizado** - FACT_METAS (DECIMAL)
- **valor_sem_desconto** - FACT_DESCONTOS (DECIMAL)
- **valor_total_bruto** - FACT_VENDAS (DECIMAL)
- **valor_total_descontos** - FACT_VENDAS (DECIMAL)
- **valor_total_liquido** - FACT_VENDAS (DECIMAL)
- **venda_id** - FACT_VENDAS (PK), FACT_DESCONTOS (FK)
- **vendedor_id** - DIM_VENDEDOR (PK), FACT_VENDAS, FACT_METAS (FK)
- **vendedor_original_id** - DIM_VENDEDOR (INT)

---

## 📚 REFERÊNCIAS CRUZADAS

### Campos Desnormalizados Intencionais

| Campo | Tabela | Origem | Motivo |
|-------|--------|--------|--------|
| nome_fornecedor | DIM_PRODUTO | DIM_FORNECEDOR (hipotética) | Performance em queries de produto |
| nome_equipe | DIM_VENDEDOR | DIM_EQUIPE | Evitar JOIN em 80% das queries |
| nome_gerente | DIM_VENDEDOR | DIM_VENDEDOR (self) | Performance em relatórios hierárquicos |
| nome_lider | DIM_EQUIPE | DIM_VENDEDOR | Evitar JOIN circular |
| cliente_id | FACT_DESCONTOS | FACT_VENDAS | Performance em análises de desconto por cliente |
| produto_id | FACT_DESCONTOS | FACT_VENDAS | Performance em análises de desconto por produto |

### Degenerate Dimensions

| Campo | Tabela | Motivo |
|-------|--------|--------|
| numero_pedido | FACT_VENDAS | Agrupamento de itens do pedido, não justifica dimensão separada |
| numero_pedido | FACT_DESCONTOS | Rastreabilidade com FACT_VENDAS |

### Campos Calculados vs Armazenados

| Campo | Tabela | Tipo | Fórmula |
|-------|--------|------|---------|
| valor_total_liquido | FACT_VENDAS | Armazenado | `valor_total_bruto - valor_total_descontos` |
| valor_comissao | FACT_VENDAS | Armazenado | `valor_total_liquido × (percentual_comissao/100)` |
| percentual_atingido | FACT_METAS | Armazenado | `(valor_realizado / valor_meta) × 100` |
| gap_meta | FACT_METAS | Armazenado | `valor_realizado - valor_meta` |
| impacto_margem | FACT_DESCONTOS | Armazenado | `margem_apos_desconto - margem_antes_desconto` |
| lucro_bruto | (calculado) | View | `valor_total_liquido - custo_total` |
| margem_percentual | (calculado) | View | `(lucro_bruto / valor_total_liquido) × 100` |

**Razão para armazenar vs calcular:**
- ✅ Armazenados: Usados frequentemente, complexos de calcular, constraint de integridade
- ❌ Calculados: Simples, usados esporadicamente, derivados de campos armazenados

---

## ⚠️ CONVENÇÕES E PADRÕES

### Nomenclatura

| Elemento | Padrão | Exemplo |
|----------|--------|---------|
| Tabelas | UPPER_CASE com prefixo | `DIM_CLIENTE`, `FACT_VENDAS` |
| Campos | snake_case | `nome_cliente`, `valor_total_liquido` |
| PKs | `[tabela]_id` | `cliente_id`, `venda_id` |
| FKs | Mesmo nome da PK referenciada | `cliente_id` em FACT aponta para `cliente_id` em DIM |
| Views | Prefixo `VW_` | `VW_VENDAS_COMPLETA` |
| Schemas | Minúsculas | `dim`, `fact` |

### Tipos de Dados Padronizados

| Uso | Tipo SQL Server | Exemplo |
|-----|-----------------|---------|
| IDs (dimensões) | `INT IDENTITY(1,1)` | `cliente_id INT` |
| IDs (facts) | `BIGINT IDENTITY(1,1)` | `venda_id BIGINT` |
| Valores monetários | `DECIMAL(15,2)` | `valor_total_liquido DECIMAL(15,2)` |
| Percentuais | `DECIMAL(5,2)` | `percentual_comissao DECIMAL(5,2)` |
| Textos curtos | `VARCHAR(n)` | `nome_cliente VARCHAR(200)` |
| Textos fixos | `CHAR(n)` | `estado CHAR(2)` |
| Datas | `DATE` | `data_cadastro DATE` |
| Timestamps | `DATETIME` | `data_inclusao DATETIME` |
| Flags | `BIT` | `eh_ativo BIT` |

### Defaults Padrão

| Campo | Default | Motivo |
|-------|---------|--------|
| `eh_ativo` | `1` | Registros novos são ativos por padrão |
| `data_inclusao` | `GETDATE()` | Auditoria automática |
| `data_ultima_atualizacao` | `GETDATE()` | Auditoria automática |
| Valores monetários | `0` | Evitar NULLs em agregações |
| Quantidades | `0` | Evitar NULLs em agregações |

---

## 📖 GLOSSÁRIO DE TERMOS

| Termo | Definição |
|-------|-----------|
| **Surrogate Key** | Chave artificial gerada pelo DW (não vem do sistema fonte). Exemplo: `cliente_id INT IDENTITY` |
| **Natural Key** | Chave do sistema origem. Exemplo: `cliente_original_id` (CPF, código ERP) |
| **Foreign Key (FK)** | Campo que referencia a PK de outra tabela |
| **Degenerate Dimension (DD)** | Atributo descritivo que fica na fact por não justificar dimensão separada. Exemplo: `numero_pedido` |
| **Granularidade** | O que 1 linha da tabela representa. Exemplo: "1 item vendido em 1 pedido" |
| **SCD Type 1** | Slowly Changing Dimension que sobrescreve valores (sem histórico) |
| **SCD Type 2** | Slowly Changing Dimension que mantém histórico completo (múltiplas versões) |
| **Fact Table** | Tabela que armazena métricas/eventos mensuráveis |
| **Dimension Table** | Tabela que descreve contexto (quem, o que, onde, quando) |
| **Star Schema** | Modelo com fact no centro e dimensions ao redor (formato de estrela) |
| **Snowflake Schema** | Star schema com dimensões normalizadas (menos usado, mais complexo) |
| **Additive Measure** | Métrica somável em todas dimensões. Exemplo: `quantidade_vendida` |
| **Semi-Additive Measure** | Métrica somável apenas em algumas dimensões. Exemplo: `valor_meta` (não somar entre períodos) |
| **Non-Additive Measure** | Métrica não somável, deve recalcular. Exemplo: `percentual_atingido` |
| **Transaction Fact** | Fact que registra eventos conforme ocorrem. Exemplo: FACT_VENDAS |
| **Periodic Snapshot** | Fact que congela estado em intervalos regulares. Exemplo: FACT_METAS |
| **Drill-Down** | Detalhar de agregado para granular. Exemplo: Ano → Mês → Dia |
| **Roll-Up** | Agregar de granular para agregado. Exemplo: Dia → Mês → Ano |
| **Desnormalização** | Armazenar dados redundantes intencionalmente para performance |
| **ETL** | Extract, Transform, Load - processo de carga de dados |
| **OLAP** | Online Analytical Processing - sistemas analíticos |
| **OLTP** | Online Transaction Processing - sistemas transacionais |

---

<div align="center">

**[⬆ Voltar ao topo](#-dicionário-de-dados---dw-e-commerce)**

**DICIONÁRIO DE DADOS COMPLETO**  
*Versão 1.0 - Última atualização: Janeiro 2026*  

📚 **Projeto:** Data Warehouse E-commerce  
🏗️ **Arquitetura:** Star Schema (Metodologia Kimball)  
📊 **Total:** 10 tabelas | ~180 campos | 15 relacionamentos  

</div>
