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
| **Nome** | Nome técnico do campo |
| **Tipo** | Tipo de dados SQL Server |
| **Obrigatório** | NULL ou NOT NULL |
| **Descrição** | O que o campo representa |
| **Valores** | Valores válidos ou exemplo |
| **Regras** | Constraints e validações |
| **Origem** | Sistema fonte (quando aplicável) |

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
**Registros:** ~3.650 (10 anos: 2020-2030)  
**Crescimento:** Planejado (adição manual de anos futuros)

### Campos

| Campo | Tipo | Obr. | Descrição | Exemplo | Regras |
|-------|------|------|-----------|---------|--------|
| 🔑 **data_id** | INT | ✓ | PK - Formato YYYYMMDD | `20241231` | PRIMARY KEY, formato date integer |
| 📝 **data_completa** | DATE | ✓ | Data no formato padrão | `2024-12-31` | UNIQUE |
| 📝 **ano** | INT | ✓ | Ano (4 dígitos) | `2024` | `>= 2020 AND <= 2030` |
| 📝 **trimestre** | INT | ✓ | Trimestre do ano | `4` | `BETWEEN 1 AND 4` |
| 📝 **mes** | INT | ✓ | Mês (número) | `12` | `BETWEEN 1 AND 12` |
| 📝 **nome_mes** | VARCHAR(20) | ✓ | Nome do mês por extenso | `"Dezembro"` | Lista fixa de 12 meses |
| 📝 **dia_mes** | INT | ✓ | Dia do mês | `31` | `BETWEEN 1 AND 31` |
| 📝 **dia_ano** | INT | ✓ | Dia do ano (ordinal) | `365` | `BETWEEN 1 AND 366` |
| 📝 **dia_semana** | INT | ✓ | Dia da semana (1=Dom) | `7` | `BETWEEN 1 AND 7` |
| 📝 **nome_dia_semana** | VARCHAR(20) | ✓ | Nome do dia por extenso | `"Sábado"` | Lista fixa de 7 dias |
| 🏷️ **eh_fim_de_semana** | BIT | ✓ | 1=Sáb/Dom, 0=Útil | `1` | Calculado: dia_semana IN (1,7) |
| 🏷️ **eh_feriado** | BIT | ✓ | 1=Feriado nacional | `1` | Lista de feriados brasileiros |
| 📝 **nome_feriado** | VARCHAR(50) | ✗ | Nome do feriado | `"Natal"` | NULL se não é feriado |

**Hierarquia Temporal:**
```
ano → trimestre → mes → dia_mes
                      → dia_semana
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
| 🔗 **cliente_original_id** | INT | ✓ | Natural Key (sistema CRM) | `45123` | UNIQUE, origem: CRM |
| 📝 **nome_cliente** | VARCHAR(200) | ✓ | Nome completo ou razão social | `"João Silva"` | `LEN >= 3` |
| 📝 **email** | VARCHAR(255) | ✓ | Email principal | `"joao@email.com"` | UNIQUE, formato email |
| 📝 **tipo_cliente** | VARCHAR(20) | ✓ | Pessoa Física ou Jurídica | `"PF"` | `IN ('PF', 'PJ')` |
| 📝 **segmento** | VARCHAR(30) | ✗ | Classificação de valor | `"Ouro"` | `IN ('Bronze','Prata','Ouro','Platinum','Corporativo','Enterprise')` |
| 📝 **pais** | VARCHAR(50) | ✓ | País de origem | `"Brasil"` | Default: 'Brasil' |
| 📝 **estado** | CHAR(2) | ✗ | UF do cliente | `"SP"` | `LEN = 2`, códigos IBGE |
| 📝 **cidade** | VARCHAR(100) | ✗ | Cidade do cliente | `"São Paulo"` | - |
| 🗓️ **data_cadastro** | DATE | ✓ | Data de registro no sistema | `2024-01-15` | `<= GETDATE()` |
| 🗓️ **data_ultima_compra** | DATE | ✗ | Última transação | `2024-12-10` | Atualizado por ETL |
| 🏷️ **eh_ativo** | BIT | ✓ | Status do cliente | `1` | Default: 1, 0=Inativo |

**Origem:** Sistema CRM (Salesforce/Dynamics)

**Segmentação por Valor (Regra de Negócio):**
- Bronze: < R$ 1.000 lifetime value
- Prata: R$ 1.000 - R$ 10.000
- Ouro: R$ 10.000 - R$ 50.000
- Platinum: > R$ 50.000
- Corporativo: PJ pequeno/médio porte
- Enterprise: PJ grande porte

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
| 🔗 **produto_original_id** | INT | ✓ | Natural Key (sistema ERP) | `78945` | UNIQUE, origem: ERP |
| 📝 **codigo_sku** | VARCHAR(50) | ✓ | Stock Keeping Unit | `"DELL-INSP-15"` | UNIQUE |
| 📝 **nome_produto** | VARCHAR(200) | ✓ | Nome descritivo completo | `"Notebook Dell Inspiron 15"` | - |
| 📝 **categoria** | VARCHAR(50) | ✓ | Categoria principal (nível 1) | `"Eletrônicos"` | - |
| 📝 **subcategoria** | VARCHAR(50) | ✗ | Subcategoria (nível 2) | `"Notebooks"` | - |
| 📝 **marca** | VARCHAR(50) | ✗ | Marca do produto | `"Dell"` | - |
| 🔗 **fornecedor_id** | INT | ✗ | ID do fornecedor | `123` | Origem: ERP |
| 📝 **nome_fornecedor** | VARCHAR(100) | ✗ | Nome do fornecedor (desnorm.) | `"Dell Inc."` | Desnormalizado |
| 📊 **peso_kg** | DECIMAL(10,2) | ✗ | Peso em quilogramas | `2.50` | `>= 0` |
| 📝 **dimensoes** | VARCHAR(50) | ✗ | Dimensões físicas | `"35x25x2 cm"` | Formato livre |
| 📊 **preco_sugerido** | DECIMAL(10,2) | ✗ | Preço de tabela atual | `3500.00` | `> 0` |
| 📊 **custo_medio** | DECIMAL(10,2) | ✗ | Custo médio unitário | `2000.00` | `> 0` |
| 🏷️ **eh_ativo** | BIT | ✓ | Produto ativo no catálogo | `1` | Default: 1 |

**Hierarquia de Categorização:**
```
categoria → subcategoria → marca → produto → SKU
```

**Origem:** Sistema ERP (SAP/TOTVS)

**Regra de Margem:**
```sql
margem = (preco_sugerido - custo_medio) / preco_sugerido * 100
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
| 📝