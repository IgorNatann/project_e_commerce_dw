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

Cada campo est? documentado com:

| Elemento | Descri??o |
|----------|-----------|
| **Campo** | Nome t?cnico do campo |
| **Tipo** | Tipo de dados SQL Server |
| **Obrigat?rio** | NULL ou NOT NULL |
| **Descri??o** | O que o campo representa |
| **Exemplo** | Valor v?lido ou exemplo |
| **Regras** | Constraints e valida??es |

**Origem:** quando aplic?vel, indicada no rodap? de cada tabela.


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

## DIM_DATA - Dimens?o Temporal

**Schema:** `dim.DIM_DATA`  
**Registros:** ~2.192 (2020-2025)  
**Crescimento:** Gerado por script; ampliar intervalo conforme necess?rio

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **data_id** | INT | ? | PK surrogate (IDENTITY) | `1` | PRIMARY KEY |
| ?? **data_completa** | DATE | ? | Data completa | `2024-12-31` | UNIQUE |
| ?? **ano** | INT | ? | Ano (4 d?gitos) | `2024` | `>= 2020` |
| ?? **trimestre** | INT | ? | Trimestre do ano | `4` | `BETWEEN 1 AND 4` |
| ?? **mes** | INT | ? | M?s (1-12) | `12` | `BETWEEN 1 AND 12` |
| ?? **dia** | INT | ? | Dia do m?s | `31` | `BETWEEN 1 AND 31` |
| ?? **semana_do_ano** | INT | ? | Semana do ano | `52` | `BETWEEN 1 AND 53` |
| ?? **dia_da_semana** | INT | ? | Dia da semana (1=Dom) | `7` | `BETWEEN 1 AND 7` |
| ?? **nome_mes** | VARCHAR(20) | ? | Nome do m?s | `Dezembro` | - |
| ?? **nome_mes_abrev** | VARCHAR(3) | ? | Abrevia??o do m?s | `Dez` | - |
| ?? **nome_dia_semana** | VARCHAR(20) | ? | Nome do dia | `S?bado` | - |
| ?? **nome_dia_semana_abrev** | VARCHAR(3) | ? | Abrevia??o do dia | `S?b` | - |
| ??? **eh_fim_de_semana** | BIT | ? | Flag fim de semana | `1` | 1=Sim, 0=N?o |
| ??? **eh_feriado** | BIT | ? | Flag feriado nacional | `1` | 1=Sim, 0=N?o |
| ?? **nome_feriado** | VARCHAR(50) | ? | Nome do feriado | `Natal` | NULL se n?o feriado |
| ?? **dia_do_ano** | INT | ? | Dia do ano (ordinal) | `365` | `BETWEEN 1 AND 366` |
| ??? **eh_ano_bissexto** | BIT | ? | Ano bissexto | `1` | 1=Sim, 0=N?o |
| ?? **periodo_mes** | VARCHAR(7) | ? | Ano-M?s formatado | `2024-12` | `YYYY-MM` |
| ?? **periodo_trimestre** | VARCHAR(7) | ? | Ano-Trimestre formatado | `2024-Q4` | `YYYY-Qn` |

**Hierarquia Temporal:**
```
ano -> trimestre -> mes -> dia
ano -> semana_do_ano
```

**Origem:** Gerada pelo script (n?o vem de sistema fonte)

---


## DIM_CLIENTE - Dimens?o Cliente

**Schema:** `dim.DIM_CLIENTE`  
**Registros Estimados:** 10.000 - 1.000.000  
**Crescimento:** Alto (novos clientes diariamente)  
**SCD Type:** Type 1 (sobrescreve)

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **cliente_id** | INT | ? | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| ?? **cliente_original_id** | INT | ? | Natural Key do sistema de origem | `45123` | UNIQUE |
| ?? **nome_cliente** | VARCHAR(100) | ? | Nome completo ou raz?o social | `Jo?o Silva` | - |
| ?? **email** | VARCHAR(100) | ? | Email principal | `joao@email.com` | - |
| ?? **telefone** | VARCHAR(20) | ? | Telefone | `(11) 98765-4321` | - |
| ?? **cpf_cnpj** | VARCHAR(18) | ? | CPF ou CNPJ | `123.456.789-00` | - |
| ??? **data_nascimento** | DATE | ? | Data de nascimento | `1985-03-15` | - |
| ?? **genero** | CHAR(1) | ? | G?nero | `M` | `IN ('M','F','O')` |
| ?? **tipo_cliente** | VARCHAR(20) | ? | Novo, Recorrente, VIP ou Inativo | `Recorrente` | `IN ('Novo','Recorrente','VIP','Inativo')` |
| ?? **segmento** | VARCHAR(20) | ? | Pessoa F?sica ou Jur?dica | `Pessoa F?sica` | `IN ('Pessoa F?sica','Pessoa Jur?dica')` |
| ?? **score_credito** | INT | ? | Score de cr?dito | `850` | `>= 0` |
| ?? **categoria_valor** | VARCHAR(20) | ? | Categoria de valor | `Ouro` | `IN ('Bronze','Prata','Ouro','Platinum')` |
| ?? **endereco_completo** | VARCHAR(200) | ? | Logradouro | `Av. Paulista, 1000` | - |
| ?? **numero** | VARCHAR(10) | ? | N?mero | `1000` | - |
| ?? **complemento** | VARCHAR(50) | ? | Complemento | `Apto 12` | - |
| ?? **bairro** | VARCHAR(50) | ? | Bairro | `Bela Vista` | - |
| ?? **cidade** | VARCHAR(100) | ? | Cidade | `S?o Paulo` | - |
| ?? **estado** | CHAR(2) | ? | UF | `SP` | `LEN = 2` |
| ?? **pais** | VARCHAR(50) | ? | Pa?s | `Brasil` | Default: `Brasil` |
| ?? **cep** | VARCHAR(10) | ? | CEP | `01310-100` | - |
| ??? **data_primeiro_cadastro** | DATE | ? | Data do primeiro cadastro | `2020-01-15` | - |
| ??? **data_ultima_compra** | DATE | ? | ?ltima compra | `2024-11-28` | - |
| ??? **data_ultima_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-12-15 10:00:00` | - |
| ?? **total_compras_historico** | INT | ? | Total de compras hist?ricas | `145` | `>= 0` |
| ?? **valor_total_gasto_historico** | DECIMAL(12,2) | ? | Valor total gasto | `87500.00` | `>= 0` |
| ?? **ticket_medio_historico** | DECIMAL(10,2) | ? | Ticket m?dio | `603.45` | - |
| ??? **eh_ativo** | BIT | ? | Status do cliente | `1` | 1=Ativo, 0=Inativo |
| ??? **aceita_email_marketing** | BIT | ? | Opt-in de marketing | `1` | 1=Sim, 0=N?o |
| ??? **eh_cliente_vip** | BIT | ? | Flag de cliente VIP | `1` | 1=Sim, 0=N?o |

**Origem:** Sistema transacional/CRM

**Tipo de Cliente (tipo_cliente):**
- Novo: primeira compra
- Recorrente: 2+ compras
- VIP: alto valor
- Inativo: sem compra recente

**Categoria de Valor (categoria_valor):**
- Bronze: at? R$ 1.000
- Prata: R$ 1.000 - R$ 10.000
- Ouro: R$ 10.000 - R$ 50.000
- Platinum: acima de R$ 50.000

---


## DIM_PRODUTO - Dimens?o Produto

**Schema:** `dim.DIM_PRODUTO`  
**Registros Estimados:** 1.000 - 100.000  
**Crescimento:** M?dio (novos produtos mensalmente)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **produto_id** | INT | ? | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| ?? **produto_original_id** | INT | ? | Natural Key do ERP | `78945` | UNIQUE |
| ?? **codigo_sku** | VARCHAR(50) | ? | Stock Keeping Unit | `DELL-NB-INS15-001` | UNIQUE |
| ?? **codigo_barras** | VARCHAR(20) | ? | EAN/UPC | `7891234567890` | - |
| ?? **nome_produto** | VARCHAR(150) | ? | Nome do produto | `Notebook Dell Inspiron 15` | - |
| ?? **descricao_curta** | VARCHAR(255) | ? | Descri??o curta | `Notebook i5 8GB 256GB` | - |
| ?? **descricao_completa** | VARCHAR(MAX) | ? | Descri??o completa | `Detalhes t?cnicos...` | - |
| ?? **categoria** | VARCHAR(50) | ? | Categoria principal | `Eletr?nicos` | - |
| ?? **subcategoria** | VARCHAR(50) | ? | Subcategoria | `Notebooks` | - |
| ?? **linha_produto** | VARCHAR(50) | ? | Linha do produto | `Linha Inspiron` | - |
| ?? **marca** | VARCHAR(50) | ? | Marca | `Dell` | - |
| ?? **fabricante** | VARCHAR(100) | ? | Fabricante | `Dell Inc.` | - |
| ?? **fornecedor_id** | INT | ? | ID do fornecedor | `101` | - |
| ?? **nome_fornecedor** | VARCHAR(100) | ? | Nome do fornecedor | `Tech Supply` | - |
| ?? **pais_origem** | VARCHAR(50) | ? | Pa?s de origem | `Estados Unidos` | - |
| ?? **peso_kg** | DECIMAL(8,3) | ? | Peso em kg | `2.150` | `>= 0` |
| ?? **altura_cm** | DECIMAL(6,2) | ? | Altura em cm | `2.50` | `>= 0` |
| ?? **largura_cm** | DECIMAL(6,2) | ? | Largura em cm | `35.80` | `>= 0` |
| ?? **profundidade_cm** | DECIMAL(6,2) | ? | Profundidade em cm | `24.00` | `>= 0` |
| ?? **cor_principal** | VARCHAR(30) | ? | Cor principal | `Preto` | - |
| ?? **material** | VARCHAR(50) | ? | Material | `Mesh/Borracha` | - |
| ?? **preco_custo** | DECIMAL(10,2) | ? | Custo de aquisi??o | `2400.00` | `>= 0` |
| ?? **preco_sugerido** | DECIMAL(10,2) | ? | Pre?o de tabela | `3499.00` | `>= 0` |
| ?? **margem_sugerida_percent** | DECIMAL(5,2) | ? | Margem sugerida (%) | `31.42` | `BETWEEN 0 AND 100` |
| ??? **eh_perecivel** | BIT | ? | Produto perec?vel | `0` | 1=Sim, 0=N?o |
| ??? **eh_fragil** | BIT | ? | Produto fr?gil | `1` | 1=Sim, 0=N?o |
| ??? **requer_refrigeracao** | BIT | ? | Precisa refrigerar | `0` | 1=Sim, 0=N?o |
| ?? **idade_minima_venda** | INT | ? | Idade m?nima | `18` | - |
| ?? **estoque_minimo** | INT | ? | Estoque m?nimo | `5` | `>= 0` |
| ?? **estoque_maximo** | INT | ? | Estoque m?ximo | `100` | `>= estoque_minimo` |
| ?? **prazo_reposicao_dias** | INT | ? | Prazo de reposi??o | `15` | - |
| ?? **situacao** | VARCHAR(20) | ? | Status | `Ativo` | `IN ('Ativo','Inativo','Descontinuado')` |
| ??? **data_lancamento** | DATE | ? | Data de lan?amento | `2023-06-15` | - |
| ??? **data_descontinuacao** | DATE | ? | Data de descontinua??o | `2018-12-31` | - |
| ??? **data_cadastro** | DATETIME | ? | Data de cadastro | `2024-01-01 00:00:00` | - |
| ??? **data_ultima_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-12-15 09:00:00` | - |
| ?? **palavras_chave** | VARCHAR(200) | ? | Palavras-chave | `notebook, i5, 8gb` | - |
| ?? **avaliacao_media** | DECIMAL(2,1) | ? | Avalia??o m?dia | `4.5` | `BETWEEN 0 AND 5` |
| ?? **total_avaliacoes** | INT | ? | Total de avalia??es | `127` | `>= 0` |

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

## DIM_DESCONTO - Dimens?o Desconto

**Schema:** `dim.DIM_DESCONTO`  
**Registros Estimados:** 100 - 1.000  
**Crescimento:** M?dio (novas campanhas)  
**SCD Type:** Type 1

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **desconto_id** | INT | ? | PK - Surrogate Key | `1` | PRIMARY KEY IDENTITY |
| ?? **desconto_original_id** | INT | ? | Natural Key (Marketing) | `7890` | UNIQUE |
| ?? **codigo_desconto** | VARCHAR(50) | ? | C?digo do cupom | `BLACKFRIDAY2024` | UNIQUE |
| ?? **nome_campanha** | VARCHAR(150) | ? | Nome da campanha | `Black Friday 2024` | - |
| ?? **descricao** | VARCHAR(500) | ? | Descri??o da promo??o | `15% em toda loja` | - |
| ?? **tipo_desconto** | VARCHAR(30) | ? | Natureza do desconto | `Cupom` | `IN ('Cupom','Promo??o Autom?tica','Desconto Progressivo','Fidelidade','Primeira Compra','Cashback')` |
| ?? **metodo_desconto** | VARCHAR(30) | ? | Como ? calculado | `Percentual` | `IN ('Percentual','Valor Fixo','Frete Gr?tis','Brinde','Combo')` |
| ?? **valor_desconto** | DECIMAL(10,2) | ? | Valor do desconto | `15.00` | `> 0` ou NULL |
| ?? **min_valor_compra_regra** | DECIMAL(15,2) | ? | M?nimo do pedido | `200.00` | - |
| ?? **max_valor_desconto_regra** | DECIMAL(15,2) | ? | Teto do desconto | `100.00` | - |
| ?? **max_usos_por_cliente** | INT | ? | Limite por cliente | `1` | - |
| ?? **max_usos_total** | INT | ? | Limite global | `1000` | - |
| ?? **aplica_em** | VARCHAR(30) | ? | Escopo do desconto | `Pedido Total` | `IN ('Pedido Total','Produto Espec?fico','Categoria','Frete','Item Individual')` |
| ?? **restricao_produtos** | VARCHAR(500) | ? | Produtos/categorias eleg?veis | `Eletr?nicos,Inform?tica` | - |
| ?? **restricao_clientes** | VARCHAR(500) | ? | Restri??es de p?blico | `Novos Clientes` | - |
| ??? **data_inicio_validade** | DATETIME | ? | In?cio da validade | `2024-11-25 00:00:00` | - |
| ??? **data_fim_validade** | DATETIME | ? | Fim da validade | `2024-11-29 23:59:59` | - |
| ?? **origem_campanha** | VARCHAR(50) | ? | Origem da campanha | `Marketing Digital` | - |
| ?? **canal_divulgacao** | VARCHAR(50) | ? | Canal de divulga??o | `Instagram` | - |
| ?? **total_usos_realizados** | INT | ? | Total de usos | `250` | `>= 0` |
| ?? **total_receita_gerada** | DECIMAL(15,2) | ? | Receita gerada | `125000.00` | `>= 0` |
| ?? **total_desconto_concedido** | DECIMAL(15,2) | ? | Total concedido | `15000.00` | `>= 0` |
| ?? **situacao** | VARCHAR(20) | ? | Status do cupom | `Ativo` | `IN ('Ativo','Pausado','Expirado','Esgotado','Cancelado')` |
| ??? **eh_ativo** | BIT | ? | Flag de uso | `1` | 1=Ativo, 0=Inativo |
| ??? **requer_aprovacao** | BIT | ? | Requer aprova??o | `0` | 1=Sim, 0=N?o |
| ??? **eh_cumulativo** | BIT | ? | Pode acumular | `0` | 1=Sim, 0=N?o |
| ??? **data_criacao** | DATETIME | ? | Data de cria??o | `2024-01-01 00:00:00` | - |
| ??? **data_ultima_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-12-15 10:30:00` | - |
| ?? **usuario_criador** | VARCHAR(100) | ? | Usu?rio criador | `maria.silva` | - |
| ?? **observacoes** | VARCHAR(500) | ? | Observa??es | `Campanha sazonal` | - |

**Origem:** Sistema de campanhas/marketing

**Observa??o:** o significado de `valor_desconto` depende do `metodo_desconto` (percentual, valor fixo, frete gr?tis, etc.).

---

## ?? Tabelas Fato

## FACT_VENDAS - Vendas (Transacional)

**Schema:** `fact.FACT_VENDAS`  
**Granularidade:** 1 item vendido em 1 pedido

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **venda_id** | BIGINT | ? | PK da venda (surrogate) | `1` | PRIMARY KEY IDENTITY |
| ?? **data_id** | INT | ? | FK -> DIM_DATA | `1826` | - |
| ?? **cliente_id** | INT | ? | FK -> DIM_CLIENTE | `123` | - |
| ?? **produto_id** | INT | ? | FK -> DIM_PRODUTO | `456` | - |
| ?? **regiao_id** | INT | ? | FK -> DIM_REGIAO | `789` | - |
| ?? **vendedor_id** | INT | ? | FK -> DIM_VENDEDOR | `12` | NULL = venda direta |
| ?? **quantidade_vendida** | INT | ? | Quantidade vendida | `2` | `> 0` |
| ?? **preco_unitario_tabela** | DECIMAL(10,2) | ? | Pre?o unit?rio sem desconto | `3500.00` | `>= 0` |
| ?? **valor_total_bruto** | DECIMAL(15,2) | ? | Valor antes de desconto | `7000.00` | `>= 0` |
| ?? **valor_total_descontos** | DECIMAL(15,2) | ? | Total de descontos | `700.00` | `>= 0` |
| ?? **valor_total_liquido** | DECIMAL(15,2) | ? | Valor final pago | `6300.00` | `= bruto - descontos` |
| ?? **custo_total** | DECIMAL(15,2) | ? | Custo total | `4000.00` | `>= 0` |
| ?? **quantidade_devolvida** | INT | ? | Quantidade devolvida | `1` | `>= 0` e `<= quantidade_vendida` |
| ?? **valor_devolvido** | DECIMAL(15,2) | ? | Valor devolvido | `3150.00` | `>= 0` |
| ?? **percentual_comissao** | DECIMAL(5,2) | ? | % de comiss?o | `3.50` | `BETWEEN 0 AND 100` |
| ?? **valor_comissao** | DECIMAL(15,2) | ? | Valor da comiss?o | `220.50` | - |
| ?? **numero_pedido** | VARCHAR(20) | ? | N?mero do pedido | `PED-2024-123456` | - |
| ??? **teve_desconto** | BIT | ? | Indicador de desconto | `1` | 1=Sim, 0=N?o |
| ??? **data_inclusao** | DATETIME | ? | Data de inclus?o no DW | `2024-12-31 10:00:00` | - |
| ??? **data_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-12-31 10:00:00` | - |

**Origem:** Sistema de vendas + c?lculos ETL

---

## FACT_METAS - Metas (Snapshot Peri?dico)

**Schema:** `fact.FACT_METAS`  
**Granularidade:** 1 meta por vendedor por per?odo

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **meta_id** | BIGINT | ? | PK da meta (surrogate) | `1` | PRIMARY KEY IDENTITY |
| ?? **vendedor_id** | INT | ? | FK -> DIM_VENDEDOR | `12` | - |
| ?? **data_id** | INT | ? | FK -> DIM_DATA (1? dia do per?odo) | `1826` | - |
| ?? **valor_meta** | DECIMAL(15,2) | ? | Meta em R$ | `50000.00` | `> 0` |
| ?? **quantidade_meta** | INT | ? | Meta de quantidade | `20` | - |
| ?? **valor_realizado** | DECIMAL(15,2) | ? | Valor realizado | `52500.00` | `>= 0` |
| ?? **quantidade_realizada** | INT | ? | Quantidade realizada | `22` | `>= 0` |
| ?? **percentual_atingido** | DECIMAL(5,2) | ? | % da meta atingida | `105.00` | `>= 0` |
| ?? **gap_meta** | DECIMAL(15,2) | ? | Diferen?a meta x realizado | `2500.00` | - |
| ?? **ticket_medio_realizado** | DECIMAL(10,2) | ? | Ticket m?dio | `2386.36` | - |
| ?? **ranking_periodo** | INT | ? | Ranking no per?odo | `1` | 1=melhor |
| ?? **quartil_performance** | VARCHAR(10) | ? | Quartil de performance | `Q1` | `IN ('Q1','Q2','Q3','Q4')` |
| ??? **meta_batida** | BIT | ? | Meta atingida | `1` | `percentual_atingido >= 100` |
| ??? **meta_superada** | BIT | ? | Meta superada | `1` | `percentual_atingido > 100` |
| ??? **eh_periodo_fechado** | BIT | ? | Per?odo fechado | `1` | 1=Sim, 0=N?o |
| ?? **tipo_periodo** | VARCHAR(20) | ? | Tipo do per?odo | `Mensal` | `IN ('Mensal','Trimestral','Anual')` |
| ?? **observacoes** | VARCHAR(500) | ? | Observa??es | `Meta ajustada` | - |
| ??? **data_inclusao** | DATETIME | ? | Data de inclus?o | `2024-12-01 00:00:00` | - |
| ??? **data_ultima_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-12-31 23:59:59` | - |

**Origem:** Metas do RH/CRM + c?lculo do realizado via FACT_VENDAS

---

## FACT_DESCONTOS - Descontos Aplicados (Eventos)

**Schema:** `fact.FACT_DESCONTOS`  
**Granularidade:** 1 desconto aplicado por venda/item

### Campos

| Campo | Tipo | Obr. | Descri??o | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| ?? **desconto_aplicado_id** | BIGINT | ? | PK da aplica??o | `1` | PRIMARY KEY IDENTITY |
| ?? **desconto_id** | INT | ? | FK -> DIM_DESCONTO | `12` | - |
| ?? **venda_id** | BIGINT | ? | FK -> FACT_VENDAS | `1450` | Fact-to-Fact |
| ?? **data_aplicacao_id** | INT | ? | FK -> DIM_DATA | `1826` | - |
| ?? **cliente_id** | INT | ? | FK -> DIM_CLIENTE | `123` | - |
| ?? **produto_id** | INT | ? | FK -> DIM_PRODUTO | `456` | NULL = pedido/frete |
| ?? **nivel_aplicacao** | VARCHAR(30) | ? | N?vel do desconto | `Item` | `IN ('Item','Pedido','Frete','Categoria')` |
| ?? **valor_desconto_aplicado** | DECIMAL(15,2) | ? | Valor concedido | `300.00` | `>= 0` |
| ?? **valor_sem_desconto** | DECIMAL(15,2) | ? | Valor antes do desconto | `3000.00` | `>= 0` |
| ?? **valor_com_desconto** | DECIMAL(15,2) | ? | Valor final | `2700.00` | `= sem_desconto - desconto` |
| ?? **margem_antes_desconto** | DECIMAL(15,2) | ? | Margem antes | `900.00` | - |
| ?? **margem_apos_desconto** | DECIMAL(15,2) | ? | Margem ap?s | `600.00` | - |
| ?? **impacto_margem** | DECIMAL(15,2) | ? | Impacto na margem | `300.00` | - |
| ?? **percentual_desconto_efetivo** | DECIMAL(5,2) | ? | % efetivo | `10.00` | `BETWEEN 0 AND 100` |
| ??? **desconto_aprovado** | BIT | ? | Aprovado | `1` | 1=Sim, 0=N?o |
| ?? **motivo_rejeicao** | VARCHAR(200) | ? | Motivo de rejei??o | `Limite excedido` | - |
| ?? **numero_pedido** | VARCHAR(20) | ? | N?mero do pedido | `PED-2024-123456` | - |
| ??? **data_inclusao** | DATETIME | ? | Data de inclus?o | `2024-11-25 10:00:00` | - |
| ??? **data_atualizacao** | DATETIME | ? | ?ltima atualiza??o | `2024-11-25 10:00:00` | - |

**Origem:** Aplica??o de cupons/promos + c?lculo de impacto

---

## ?? Views Auxiliares

Views para consumo e an?lise. Para detalhes de colunas e regras, consulte `sql/04_views/README.md`.

| View | Prop?sito | Origem principal |
|------|-----------|------------------|
| `dim.VW_CALENDARIO_COMPLETO` | Calend?rio completo com per?odos e flags | `dim.DIM_DATA` |
| `dim.VW_PRODUTOS_ATIVOS` | Produtos ativos para an?lise | `dim.DIM_PRODUTO` |
| `dim.VW_CATALOGO_PRODUTOS` | Cat?logo com faixa de pre?o e selo | `dim.DIM_PRODUTO` |
| `dim.VW_CLIENTES_ATIVOS` | Clientes ativos e rec?ncia | `dim.DIM_CLIENTE` |
| `dim.VW_HIERARQUIA_GEOGRAFICA` | Hierarquia geogr?fica | `dim.DIM_REGIAO` |
| `dim.VW_VENDEDORES_ATIVOS` | Vendedores ativos + equipe | `dim.DIM_VENDEDOR`, `dim.DIM_EQUIPE` |
| `dim.VW_HIERARQUIA_VENDEDORES` | Hierarquia gerencial | `dim.DIM_VENDEDOR` |
| `dim.VW_ANALISE_EQUIPE_VENDEDORES` | Indicadores por equipe | `dim.DIM_EQUIPE`, `dim.DIM_VENDEDOR` |
| `dim.VW_EQUIPES_ATIVAS` | Equipes ativas | `dim.DIM_EQUIPE` |
| `dim.VW_RANKING_EQUIPES_META` | Ranking de equipes por meta | `fact.FACT_METAS`, dimens?es |
| `dim.VW_ANALISE_REGIONAL_EQUIPES` | An?lise regional de equipes | dimens?es + fatos |
| `dim.VW_DESCONTOS_ATIVOS` | Cupons/descontos v?lidos | `dim.DIM_DESCONTO` |
| `fact.VW_VENDAS_COMPLETA` | Vendas com joins de dimens?es | `fact.FACT_VENDAS` + dims |
| `fact.VW_METAS_COMPLETA` | Metas com contexto | `fact.FACT_METAS` + dims |
| `fact.VW_DESCONTOS_COMPLETA` | Descontos aplicados com contexto | `fact.FACT_DESCONTOS` + dims |

---

## ?? Gloss?rio de Termos

- **Dimens?o:** tabela descritiva com atributos de contexto (quem, onde, quando, etc.).
- **Fato:** tabela com m?tricas num?ricas do neg?cio (vendas, metas, descontos).
- **Gr?o (Granularidade):** n?vel de detalhe de cada linha na tabela fato.
- **Star Schema:** modelo em estrela com fatos no centro e dimens?es ao redor.
- **Chave Natural:** identificador vindo do sistema de origem (ex: cliente_original_id).
- **Chave Surrogada:** identificador interno do DW (IDENTITY) sem significado de neg?cio.
- **SCD Type 1:** sobrescreve atributos quando h? mudan?a (sem hist?rico).
- **Periodic Snapshot Fact:** fato peri?dico com estado por per?odo (ex: metas mensais).
- **Transaction Fact:** fato transacional linha-a-linha (ex: itens de venda).
- **Degenerate Dimension:** atributo textual mantido na fact (ex: numero_pedido).
- **Fact-to-Fact:** relacionamento entre tabelas fato (ex: FACT_DESCONTOS -> FACT_VENDAS).
