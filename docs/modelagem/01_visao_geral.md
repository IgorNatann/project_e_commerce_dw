# 🏗️ Visão Geral da Modelagem

> Arquitetura dimensional do Data Warehouse E-commerce

## 📋 Índice

- [Conceitos Fundamentais](#conceitos-fundamentais)
- [Arquitetura Star Schema](#arquitetura-star-schema)
- [Processos de Negócio](#processos-de-negócio)
- [Granularidade](#granularidade)
- [Hierarquias](#hierarquias)
- [Tipos de Facts](#tipos-de-facts)
- [Metodologia Kimball](#metodologia-kimball)
- [Casos de Uso](#casos-de-uso)
- [Fluxo de Dados](#fluxo-de-dados)

---

## 🎯 Conceitos Fundamentais

### O que é um Data Warehouse?

Um Data Warehouse é um repositório centralizado de dados otimizado para análise e tomada de decisão. Diferente dos sistemas transacionais (OLTP) que gerenciam operações do dia a dia, o Data Warehouse é construído especificamente para responder perguntas de negócio através de análises históricas e agregações complexas.

Imagine que sua empresa possui diversos sistemas: um para vendas, outro para estoque, um terceiro para o cadastro de clientes. Cada um desses sistemas armazena dados de forma otimizada para suas operações específicas. O Data Warehouse integra todos esses dados em um único local, organizando-os de maneira que facilite análises como "Qual foi o crescimento de vendas por região nos últimos três anos?" ou "Quais produtos têm maior margem de lucro por categoria?".

### Diferenças entre OLTP e OLAP

Para entender por que precisamos de uma modelagem diferente para análises, vamos comparar os dois tipos de sistemas:

**Sistemas Transacionais (OLTP - Online Transaction Processing):**
Os sistemas OLTP, como um sistema de vendas ou de cadastro de pedidos, são otimizados para processar muitas operações pequenas e rápidas. Quando um cliente faz uma compra online, o sistema precisa registrar o pedido, atualizar o estoque, processar o pagamento - tudo isso em questão de segundos. Para isso, os dados são organizados de forma normalizada, eliminando redundâncias e garantindo que cada informação seja armazenada em apenas um lugar. Essa abordagem garante integridade e velocidade nas operações do dia a dia.

**Sistemas Analíticos (OLAP - Online Analytical Processing):**
Já os sistemas OLAP, como nosso Data Warehouse, são otimizados para responder perguntas complexas que envolvem grandes volumes de dados. Quando um executivo quer saber "Qual foi o desempenho de vendas comparando o último trimestre com o mesmo período do ano anterior, segmentado por região e categoria de produto?", essa query precisa varrer milhões de registros e fazer diversas agregações. Para tornar isso rápido, aceitamos alguma redundância nos dados e organizamos tudo de forma desnormalizada, priorizando velocidade de leitura sobre velocidade de escrita.

| Aspecto | OLTP (Transacional) | OLAP (Analítico) |
|---------|---------------------|------------------|
| **Objetivo** | Processar transações do dia a dia | Suportar análises e decisões estratégicas |
| **Operações** | Muitas escritas por segundo | Poucas escritas, muitas leituras complexas |
| **Queries** | Simples e rápidas (milissegundos) | Complexas e demoradas (segundos/minutos) |
| **Estrutura** | Normalizada (3NF) para evitar redundância | Desnormalizada (Star/Snowflake) para performance |
| **Histórico** | Dados atuais, histórico limitado | Histórico completo (anos de dados) |
| **Usuários** | Aplicações e operadores | Analistas, gerentes, executivos |
| **Exemplo** | Registrar uma venda | Analisar tendências de vendas |

### Modelagem Dimensional vs Relacional

Quando projetamos um banco de dados transacional, seguimos as regras de normalização. Isso significa dividir os dados em muitas tabelas pequenas para eliminar redundâncias. Por exemplo, em vez de repetir o nome do fornecedor em cada produto, criamos uma tabela de fornecedores e referenciamos seu ID na tabela de produtos.

No Data Warehouse, fazemos o oposto. Aceitamos repetir o nome do fornecedor em cada linha de produto porque isso torna as consultas mais rápidas. Em vez de precisar fazer um JOIN entre três ou quatro tabelas para responder uma pergunta simples, podemos buscar a informação diretamente em uma ou duas tabelas. Essa é a essência da modelagem dimensional.

A modelagem dimensional organiza os dados em duas categorias principais: tabelas fato (que contêm as métricas numéricas do negócio) e tabelas dimensão (que descrevem o contexto dessas métricas). É como organizar um relatório: as dimensões são os cabeçalhos das colunas e linhas (data, produto, região), enquanto os fatos são os números nas células (quantidade vendida, valor da venda).

---

## ⭐ Arquitetura Star Schema

### Estrutura do Nosso DW

Nosso Data Warehouse segue o padrão Star Schema, onde as tabelas fato ficam no centro, conectadas diretamente a todas as dimensões relevantes. Imagine uma estrela: no centro está a tabela fato, e cada ponta da estrela é uma dimensão. Essa estrutura é chamada de "estrela" justamente por essa aparência quando desenhamos o diagrama.

```
                    DIM_DATA (Temporal)
                    ┌─────────────┐
                    │ data_id (PK)│
                    │ ano         │
                    │ trimestre   │
                    │ mes         │
                    │ dia_semana  │
                    └──────┬──────┘
                           │
                           │ (FK)
                           │
    DIM_EQUIPE        DIM_VENDEDOR        DIM_DESCONTO
    ┌───────────┐     ┌───────────┐       ┌───────────┐
    │equipe_id  │◄────┤vendedor_id│       │desconto_id│
    │(PK)       │(FK) │(PK)       │       │(PK)       │
    │nome_equipe│     │nome       │       │codigo     │
    │regional   │     │cargo      │       │campanha   │
    │meta_mensal│     │equipe_id  │       │tipo       │
    └───────────┘     │gerente_id │◄┐     └─────┬─────┘
                      └─────┬─────┘ │           │
                            │       │(self-FK)  │
                            │(FK)   └───────────┘
                            │
         ┌──────────────────┴─────────────────────────────┐
         │                                                 │
         ▼                                                 ▼
    ┌────────────────────────────┐        ┌───────────────────────────┐
    │    FACT_VENDAS             │        │   FACT_DESCONTOS          │
    │    ┌────────────────┐      │        │   ┌────────────────┐     │
    │    │venda_id (PK)   │◄─────┼────────┼───┤venda_id (FK)   │     │
    │    │data_id (FK)────┼──┐   │        │   │desconto_id(FK)─┼──┐  │
    │    │cliente_id (FK)─┼──┼───┼────┐   │   │data_apl_id(FK)─┼──┼┐ │
    │    │produto_id (FK)─┼──┼───┼────┼───┼───┤cliente_id (FK)─┼──┼┤ │
    │    │regiao_id (FK)──┼──┼───┼────┼───┼───┤produto_id (FK)─┼──┼┤ │
    │    │vendedor_id(FK)─┼──┼───┼────┘   │   └────────────────┘  ││ │
    │    │───────────────│  │   │        └───────────────────────┘│ │
    │    │MÉTRICAS:       │  │   │                                 │ │
    │    │quantidade      │  │   │                                 │ │
    │    │valor_liquido   │  │   │                                 │ │
    │    │custo_total     │  │   │                                 │ │
    │    │valor_comissao  │  │   │                                 │ │
    │    └────────────────┘  │   │                                 │ │
    └────────────────────────┼───┘                                 │ │
                             │                                     │ │
         ┌───────────────────┼─────────────────────────────────────┘ │
         │                   │                                       │
         ▼                   ▼                                       ▼
    ┌─────────┐      ┌──────────┐      ┌──────────┐       ┌─────────┐
    │DIM_DATA │      │DIM_CLIENT│      │DIM_PRODUT│       │DIM_REGIA│
    │(tempo)  │      │(quem)    │      │(o que)   │       │(onde)   │
    └─────────┘      └──────────┘      └──────────┘       └─────────┘


         ┌──────────────────────────────────────┐
         │       FACT_METAS                     │
         │   ┌────────────────┐                 │
         │   │meta_id (PK)    │                 │
         │   │vendedor_id(FK)─┼─────────►DIM_VENDEDOR
         │   │data_id (FK)────┼─────────►DIM_DATA
         │   │───────────────│                 │
         │   │MÉTRICAS:       │                 │
         │   │valor_meta      │                 │
         │   │valor_realizado │                 │
         │   │% atingido      │                 │
         │   └────────────────┘                 │
         └──────────────────────────────────────┘
```

### Componentes da Arquitetura

**Tabelas Fato (Centro da Estrela):**
As tabelas fato armazenam as métricas numéricas do negócio - aquilo que queremos medir e analisar. Em nosso DW, temos três tabelas fato: FACT_VENDAS registra cada item vendido, FACT_METAS acompanha o desempenho dos vendedores contra suas metas mensais, e FACT_DESCONTOS rastreia cada desconto aplicado nas vendas. Cada linha em uma tabela fato representa um evento ou medição específica do negócio.

**Tabelas Dimensão (Pontas da Estrela):**
As dimensões fornecem o contexto para as métricas. Elas respondem às perguntas "quem", "o que", "onde", "quando" e "como" sobre cada fato. Por exemplo, quando registramos uma venda (um fato), precisamos saber quando ela ocorreu (DIM_DATA), quem comprou (DIM_CLIENTE), o que foi comprado (DIM_PRODUTO), onde será entregue (DIM_REGIAO) e quem vendeu (DIM_VENDEDOR). Cada dimensão contém atributos descritivos que permitem filtrar, agrupar e segmentar as análises.

### Características do Star Schema

O Star Schema oferece várias vantagens importantes para análises de negócio:

**Performance otimizada:** Como cada dimensão se conecta diretamente à tabela fato, as queries precisam fazer poucos JOINs. Quando você quer saber "vendas por categoria de produto no último trimestre", o banco de dados precisa unir apenas a FACT_VENDAS com DIM_PRODUTO e DIM_DATA - três tabelas no total. Em um modelo normalizado tradicional, essa mesma consulta poderia requerer cinco ou seis JOINs.

**Simplicidade conceitual:** A estrutura é intuitiva mesmo para usuários não-técnicos. Um analista de negócios pode facilmente entender que precisa conectar a tabela de vendas com a tabela de produtos para analisar vendas por categoria. Essa simplicidade também facilita o trabalho com ferramentas de BI, que reconhecem automaticamente o padrão Star Schema.

**Flexibilidade analítica:** Adicionar novas dimensões é simples - basta criar a nova tabela dimensão e adicionar uma foreign key na tabela fato. Isso permite que o DW evolua conforme novas necessidades analíticas surgem, sem precisar reestruturar todo o modelo.

No entanto, existem trade-offs que precisamos aceitar:

**Redundância controlada:** Informações como o nome do fornecedor podem aparecer milhares de vezes na dimensão de produtos (uma vez para cada produto daquele fornecedor). Isso ocupa mais espaço em disco do que em um modelo normalizado, mas o ganho em velocidade de consulta compensa largamente esse custo adicional.

**Espaço em disco:** Um modelo Star Schema tipicamente usa 10-15% mais espaço que um modelo normalizado equivalente. Com os custos atuais de armazenamento, isso raramente é um problema, especialmente considerando os ganhos em performance.

---

## 💼 Processos de Negócio

Cada processo de negócio no DW é modelado através de uma ou mais tabelas fato. Escolhemos três processos fundamentais para o e-commerce:

### 1️⃣ Processo: Vendas (Transacional)

O processo de vendas captura cada transação comercial em seu nível mais detalhado. Decidimos modelar no nível de item (cada produto vendido em um pedido é uma linha separada) porque isso oferece máxima flexibilidade analítica.

**Por que esse nível de detalhe?** Imagine um pedido onde o cliente comprou um notebook, um mouse e um teclado. Se armazenássemos o pedido inteiro em uma única linha, perderíamos a capacidade de analisar questões como "qual categoria de produto tem maior margem?" ou "qual produto é mais devolvido?". Com a granularidade no nível de item, podemos responder essas perguntas e ainda agregar para ver o pedido completo quando necessário.

```
FACT_VENDAS
├─ Granularidade: 1 item vendido em 1 pedido
├─ Frequência: Contínua (centenas/milhares por dia)
├─ Tipo: Transaction Fact Table
├─ Volume: Cresce linearmente com as vendas
└─ Perguntas respondidas:
   • Quanto vendemos hoje/mês/ano por categoria?
   • Quais produtos têm maior margem de lucro?
   • Como variam as vendas por região geográfica?
   • Qual a taxa de devolução por fornecedor?
   • Qual o ticket médio por segmento de cliente?
   • Como descontos impactam a margem?
```

### 2️⃣ Processo: Metas de Vendedores (Periódica)

O acompanhamento de metas funciona de forma diferente das vendas. Enquanto vendas acontecem continuamente ao longo do dia, metas são estabelecidas e medidas em períodos fixos - tipicamente mês a mês. Criamos uma tabela fato separada porque o processo é fundamentalmente diferente.

**Por que não calcular tudo na hora?** Poderíamos, teoricamente, calcular o desempenho dos vendedores somando suas vendas da FACT_VENDAS. Mas ter uma tabela FACT_METAS oferece várias vantagens: primeiro, ela congela o estado do fim de cada período (se houver correções retroativas nas vendas, ainda temos o registro do que foi reportado originalmente). Segundo, ela armazena informações que não existem na tabela de vendas, como a meta original estabelecida para aquele vendedor naquele mês. Terceiro, ela torna queries de análise de performance muito mais rápidas, pois não precisa agregar milhões de vendas toda vez.

```
FACT_METAS
├─ Granularidade: 1 meta de 1 vendedor em 1 período
├─ Frequência: Mensal (após fechamento do mês)
├─ Tipo: Periodic Snapshot Fact Table
├─ Volume: Número de vendedores × número de meses
└─ Perguntas respondidas:
   • Qual percentual da meta cada vendedor atingiu?
   • Como é o ranking de performance no trimestre?
   • Há tendência de melhora ou piora ao longo do tempo?
   • Quais vendedores consistentemente superam metas?
   • Como equipes se comparam em atingimento?
   • É possível prever atingimento futuro baseado em histórico?
```

### 3️⃣ Processo: Descontos Aplicados (Eventos)

Descontos merecem uma tabela fato própria porque uma única venda pode ter múltiplos descontos aplicados. Um cliente pode usar um cupom de 10% de desconto, ganhar mais 5% por comprar em quantidade, e ainda ter frete grátis. Se tentássemos modelar isso na FACT_VENDAS, teríamos que criar múltiplas colunas (desconto1, desconto2, desconto3) ou usar campos JSON - ambas soluções ruins.

**A solução elegante:** Criar uma tabela FACT_DESCONTOS onde cada desconto aplicado é uma linha separada. Isso permite análises sofisticadas como "qual o ROI de cada campanha de cupons?" ou "como descontos combinados afetam a margem?". A tabela se relaciona com FACT_VENDAS através do venda_id, permitindo conectar cada desconto à sua venda original.

```
FACT_DESCONTOS
├─ Granularidade: 1 desconto aplicado em 1 venda
├─ Frequência: Conforme aplicação de cupons/promoções
├─ Tipo: Transaction Fact Table (eventos discretos)
├─ Volume: Variável (depende de campanhas ativas)
└─ Perguntas respondidas:
   • Qual o retorno sobre investimento de cada campanha?
   • Como descontos impactam a margem de lucro?
   • Quais produtos são mais frequentemente descontados?
   • Qual a efetividade por tipo de desconto (%, valor fixo)?
   • Clientes que usam cupons têm ticket médio maior?
   • Quantas vendas têm múltiplos descontos aplicados?
```

---

## 🔬 Granularidade

A granularidade é possivelmente a decisão mais crítica em modelagem dimensional. Ela define o que cada linha da tabela fato representa e impacta diretamente quais análises são possíveis.

### Princípio Fundamental

A regra de ouro é escolher a granularidade mais fina que faça sentido para o negócio. Isso porque você pode sempre agregar dados detalhados para ver visões mais resumidas, mas nunca consegue "desagregar" dados que já foram resumidos. É como tirar uma foto: você pode sempre reduzir a resolução depois, mas não pode aumentar a resolução de uma foto que já foi tirada em baixa qualidade.

### FACT_VENDAS: Nível de Item

Quando decidimos a granularidade da FACT_VENDAS, tínhamos três opções principais:

**Opção A - Nível de Pedido (Descartada):**
Cada pedido completo seria uma linha. Um pedido com três produtos seria uma única linha na tabela. Essa abordagem é mais compacta (menos linhas), mas perde informação crucial. Como saberíamos qual produto específico foi mais vendido? Como calcularíamos margem por categoria? Essas análises se tornariam impossíveis ou extremamente complexas.

**Opção B - Nível de Item (Escolhida):**
Cada item em um pedido é uma linha separada. Um pedido com três produtos gera três linhas na tabela. Isso permite análises detalhadas por produto, categoria, fornecedor, etc. Podemos sempre somar para ver o pedido completo, mas mantemos a capacidade de análise detalhada quando necessária.

**Opção C - Nível de Transação de Pagamento (Descartada):**
Isso misturaria conceitos de vendas com conceitos de pagamento, dificultando análises. Um pedido pode ter múltiplas transações de pagamento (cartão + vale presente), criando confusão sobre o que cada linha representa.

### FACT_METAS: Vendedor × Período

Para metas, a granularidade natural é um vendedor em um período específico. Consideramos períodos diários, semanais e mensais:

**Por que mensal?** Metas de negócio geralmente são estabelecidas mensalmente. Ter granularidade diária criaria 30 vezes mais linhas sem agregar valor analítico real - vendedores não são avaliados dia a dia, e o ruído diário (um dia bom, outro ruim) obscureceria tendências reais. Mensal é o equilíbrio perfeito entre detalhe e utilidade.

### FACT_DESCONTOS: Cada Aplicação

A granularidade de um desconto aplicado foi escolhida porque precisamos rastrear múltiplos descontos na mesma venda. Se um cliente usa três cupons diferentes, queremos saber o impacto individual de cada um deles.

### Visualizando o Impacto da Granularidade

```
Pedido #12345 - Cliente: João Silva - Data: 2024-12-10

GRANULARIDADE NO NÍVEL DE PEDIDO (Descartada):
┌────────┬───────────┬─────────┬──────────┐
│pedido  │cliente    │valor    │qtd_itens │
├────────┼───────────┼─────────┼──────────┤
│12345   │João Silva │ 8500.00 │    3     │  ← 1 LINHA APENAS
└────────┴───────────┴─────────┴──────────┘
❌ Perdemos: Quais produtos? Qual margem de cada? Qual foi devolvido?

GRANULARIDADE NO NÍVEL DE ITEM (Escolhida):
┌────────┬────────────┬──────┬─────────┬─────────┬────────┐
│pedido  │produto     │qtd   │valor    │custo    │margem  │
├────────┼────────────┼──────┼─────────┼─────────┼────────┤
│12345   │Notebook    │  2   │ 7000.00 │ 4000.00 │ 42.9%  │
│12345   │Mouse       │  1   │ 1000.00 │  400.00 │ 60.0%  │
│12345   │Teclado     │  1   │  500.00 │  200.00 │ 60.0%  │
└────────┴────────────┴──────┴─────────┴─────────┴────────┘
✅ Mantemos: Todos os detalhes + capacidade de agregar para ver pedido completo
```

---

## 📊 Hierarquias

Hierarquias são estruturas que organizam dados em níveis do mais agregado ao mais detalhado. Elas permitem que usuários naveguem pelos dados de forma intuitiva, fazendo drill-down (detalhar) ou roll-up (agregar).

### Hierarquia Temporal (DIM_DATA)

A dimensão temporal é especialmente rica em hierarquias porque o tempo pode ser agrupado de muitas formas diferentes:

```
Ano (2024)
 └── Trimestre (Q1: Jan-Mar, Q2: Abr-Jun, Q3: Jul-Set, Q4: Out-Dez)
      └── Mês (Janeiro, Fevereiro, ...)
           └── Semana do Mês (1ª semana, 2ª semana, ...)
                └── Dia (1, 2, 3, ..., 31)
                     └── Dia da Semana (Segunda, Terça, ...)

Hierarquia Alternativa (Semanas ISO):
Ano → Semana do Ano (1-52) → Dia da Semana
```

**Exemplo prático de navegação hierárquica:**
Um executivo começa visualizando vendas anuais. Ele nota que 2024 teve performance inferior a 2023. Faz drill-down para ver por trimestre e descobre que o problema foi no Q3. Detalha para o nível mensal e identifica que agosto foi o mês problemático. Por fim, vai até o nível diário e vê que houve uma queda significativa em uma semana específica devido a problemas de estoque. Sem hierarquias, esse tipo de investigação seria muito mais difícil.

### Hierarquia Geográfica (DIM_REGIAO)

A organização geográfica do Brasil segue uma hierarquia natural:

```
País (Brasil)
 └── Região (Sudeste, Sul, Nordeste, Norte, Centro-Oeste)
      └── Estado (SP, RJ, MG, PR, RS, ...)
           └── Cidade (São Paulo, Campinas, Santos, ...)
                └── Bairro (poderia ser adicionado futuramente)
                     └── CEP (nível mais granular disponível)
```

**Utilidade analítica:**
Essa hierarquia permite perguntas em diferentes níveis de detalhe. A diretoria pode querer ver "performance por região do país" (visão macro), enquanto um gerente regional pode querer "vendas por cidade no estado de São Paulo" (visão detalhada). A mesma estrutura de dados suporta ambas as análises.

### Hierarquia de Produtos (DIM_PRODUTO)

Produtos são naturalmente organizados em categorias:

```
Categoria (Eletrônicos, Livros, Casa & Decoração, ...)
 └── Subcategoria (Notebooks, Periféricos, Acessórios, ...)
      └── Linha de Produto (Dell Inspiron, HP Pavilion, ...)
           └── Produto Específico (Dell Inspiron 15 i5 8GB)
                └── SKU (código único incluindo cor/config)
```

**Flexibilidade para análises:**
Um gerente de categoria pode analisar "eletrônicos vs livros", um comprador pode focar em "notebooks", e um analista de inventário pode trabalhar no nível de SKU individual. A hierarquia permite que cada usuário trabalhe no nível de detalhe apropriado para sua função.

### Hierarquia Organizacional

A estrutura da força de vendas também forma uma hierarquia:

```
Empresa
 └── Regional (Sudeste, Sul, Nordeste, ...)
      └── Equipe (Equipe Alpha SP, Time Beta RJ, ...)
           └── Líder de Equipe (Carlos Silva, Luciana Fernandes, ...)
                └── Vendedores (Ana Santos, Roberto Almeida, ...)
                     └── Hierarquia Gerencial Individual
                          (Vendedor → Coordenador → Gerente)
```

**Análises multinível:**
O CEO pode ver performance por regional, o diretor regional pode focar em suas equipes, e o líder de equipe pode acompanhar cada vendedor individualmente. Todos usando a mesma fonte de dados, mas em níveis apropriados de agregação.

---

## 📈 Tipos de Facts

### 1. Transaction Fact Table (Transacional)

As tabelas fato transacionais capturam eventos individuais conforme eles ocorrem no negócio. Cada venda, cada devolução, cada aplicação de desconto é registrada como uma nova linha.

**Características operacionais:**
Essas tabelas crescem continuamente. Se sua empresa faz mil vendas por dia, você adiciona mil novas linhas diariamente à FACT_VENDAS. O volume pode se tornar muito grande ao longo dos anos (milhões ou até bilhões de registros), mas isso é administrável com particionamento e arquivamento adequados.

**Exemplo: FACT_VENDAS**
```sql
-- Cada venda é uma nova linha, nunca atualizada após inserção
venda_id | data_id | cliente_id | produto_id | quantidade | valor_liquido
---------|---------|------------|------------|------------|-------------
    1    | 20241201|     5      |     10     |     2      |    7000
    2    | 20241201|     8      |     12     |     1      |    1500
    3    | 20241201|     5      |     15     |     3      |    4500
```

**Vantagens analíticas:**
A granularidade fina permite qualquer tipo de agregação. Você pode somar vendas por hora, por dia, por semana, por mês - tudo está lá nos dados. Você pode analisar padrões de compra individual do cliente ou tendências macro do mercado, usando a mesma tabela.

### 2. Periodic Snapshot Fact Table (Snapshot Periódico)

Snapshots periódicos congelam o estado das métricas em intervalos regulares. Imagine tirar uma fotografia do desempenho de cada vendedor no último dia de cada mês - isso é exatamente o que FACT_METAS faz.

**Por que não calcular sempre na hora?**
Embora pudéssemos somar vendas da FACT_VENDAS para calcular desempenho, ter um snapshot oferece várias vantagens. Primeiro, ele registra informações que não existem em transações individuais (como a meta original estabelecida). Segundo, ele preserva o histórico - se há correções retroativas nas vendas, ainda temos o registro do que foi reportado originalmente. Terceiro, torna análises muito mais rápidas, pois não precisa agregar milhões de vendas toda vez.

**Exemplo: FACT_METAS**
```sql
-- Uma linha por vendedor por período, atualizada durante o mês e congelada no final
meta_id | vendedor_id | data_id  | valor_meta | valor_realizado | % atingido
--------|-------------|----------|------------|-----------------|------------
   1    |      3      | 20241201 |   50000    |     52500       |   105.0
   2    |      3      | 20241101 |   50000    |     48000       |    96.0
   3    |      5      | 20241201 |   45000    |     47250       |   105.0
```

**Padrão de crescimento:**
O volume é previsível: número de vendedores multiplicado por número de períodos. Com 100 vendedores e 12 meses, você tem apenas 1.200 registros por ano - muito mais gerenciável que milhões de vendas.

### 3. Accumulating Snapshot Fact Table (Snapshot Acumulativo)

Este tipo de fact rastreia processos com início e fim claros, atualizando a mesma linha conforme o processo avança. Embora não implementado neste projeto, é importante conhecer para futuras expansões.

**Quando usar:**
Processos com múltiplas etapas e marcos temporais, como:
- Processamento de pedidos: pedido feito → pagamento aprovado → separado no estoque → enviado → entregue
- Pipeline de vendas: lead capturado → qualificado → proposta enviada → negociação → fechado
- Produção: ordem criada → materiais separados → produção iniciada → controle qualidade → finalizado

**Características únicas:**
Ao contrário das facts transacionais (insert-only) e snapshots periódicos (insert mensal), accumulating snapshots são atualizadas conforme o processo progride. A mesma linha ganha novas datas conforme passa por cada etapa.

---

## 🎓 Metodologia Kimball

Ralph Kimball, um dos pioneiros da modelagem dimensional, definiu um processo estruturado em 4 etapas para construir um Data Warehouse. Seguimos rigorosamente essa metodologia:

### Passo 1: Selecionar o Processo de Negócio

O primeiro passo é identificar qual processo de negócio você quer analisar. Não comece pensando em "quero um banco de dados de vendas", mas sim "quero analisar o processo de vendas para entender padrões de compra e performance".

**Nossos processos escolhidos:**
- **Vendas:** O processo core do e-commerce - desde a visita do cliente até a entrega do produto
- **Gestão de Performance:** Acompanhamento de metas e desempenho da força de vendas
- **Campanhas Promocionais:** Efetividade de descontos e cupons

Cada processo tornou-se uma tabela fato separada porque têm granularidades e ciclos de vida diferentes.

### Passo 2: Definir a Granularidade

Para cada processo, definimos precisamente o que cada linha representa. Essa é a decisão que mais impacta as análises futuras.

**FACT_VENDAS:** "Uma linha representa um item de um produto específico em um pedido específico"
- ✅ Permite: Analisar produtos, categorias, fornecedores individualmente
- ❌ Não permite: Perde alguma informação sobre o pedido como um todo (resolvido com número_pedido como degenerate dimension)

**FACT_METAS:** "Uma linha representa a meta de um vendedor específico em um mês específico"
- ✅ Permite: Tendências mensais, comparações entre vendedores
- ❌ Não permite: Ver flutuações intra-mês (aceito como trade-off)

**FACT_DESCONTOS:** "Uma linha representa um desconto específico aplicado em uma venda"
- ✅ Permite: Múltiplos descontos por venda, ROI por campanha
- ❌ Não permite: N/A (granularidade ideal para o caso de uso)

### Passo 3: Identificar as Dimensões

Dimensões respondem às perguntas sobre cada fato. Usamos o framework das "perguntas jornalísticas":

**Perguntas para FACT_VENDAS:**
- Quando? → DIM_DATA
- Quem comprou? → DIM_CLIENTE  
- O que comprou? → DIM_PRODUTO
- Onde será entregue? → DIM_REGIAO
- Quem vendeu? → DIM_VENDEDOR
- Como pagou? → (futuro: DIM_FORMA_PAGAMENTO)
- Por qual canal? → (futuro: DIM_CANAL)

**Perguntas para FACT_METAS:**
- Quando? → DIM_DATA
- Quem? → DIM_VENDEDOR
- De qual equipe? → DIM_EQUIPE (transitivo via DIM_VENDEDOR)

**Perguntas para FACT_DESCONTOS:**
- Quando aplicado? → DIM_DATA
- Qual desconto? → DIM_DESCONTO
- Em qual venda? → FACT_VENDAS (relacionamento fact-to-fact)
- Para qual cliente? → DIM_CLIENTE
- Em qual produto? → DIM_PRODUTO

### Passo 4: Identificar as Métricas (Fatos)

Métricas são os números que queremos analisar - as medidas quantitativas do negócio.

**FACT_VENDAS:**
- Quantidade vendida (aditiva - pode somar em todas dimensões)
- Valor total bruto (aditivo)
- Valor total de descontos (aditivo)
- Valor total líquido (aditivo)
- Custo total (aditivo)
- Quantidade devolvida (aditiva)
- Valor devolvido (aditivo)
- Valor de comissão (aditivo)

**FACT_METAS:**
- Valor da meta (semi-aditiva - não faz sentido somar metas de meses diferentes)
- Valor realizado (aditiva)
- Percentual atingido (não-aditiva - deve ser recalculado)
- Gap da meta (semi-aditiva)

**FACT_DESCONTOS:**
- Valor do desconto aplicado (aditiva)
- Margem antes do desconto (semi-aditiva)
- Margem após desconto (semi-aditiva)
- Impacto na margem (aditiva)

---

## 🎯 Casos de Uso

Para ilustrar o poder da modelagem dimensional, vejamos alguns cenários reais de análise:

### Caso de Uso 1: Análise de Sazonalidade

**Necessidade de Negócio:**
O gerente de marketing precisa planejar campanhas e estoques entendendo padrões sazonais de vendas.

**Como o DW resolve:**
```sql
-- Comparar vendas mês a mês, identificando picos e vales
SELECT 
    d.ano,
    d.nome_mes,
    d.mes,
    SUM(fv.valor_total_liquido) AS receita,
    LAG(SUM(fv.valor_total_liquido)) OVER (
        PARTITION BY d.mes 
        ORDER BY d.ano
    ) AS receita_ano_anterior,
    ((SUM(fv.valor_total_liquido) - LAG(SUM(fv.valor_total_liquido)) OVER (
        PARTITION BY d.mes ORDER BY d.ano
    )) / LAG(SUM(fv.valor_total_liquido)) OVER (
        PARTITION BY d.mes ORDER BY d.ano
    ) * 100) AS crescimento_yoy
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_DATA d ON fv.data_id = d.data_id
WHERE d.ano IN (2023, 2024)
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.mes, d.ano;
```

**Insights possíveis:**
- Dezembro sempre tem pico (Black Friday + Natal)
- Janeiro tem queda natural após festas
- Identificar meses que fogem do padrão histórico
- Planejar estoque baseado em padrões comprovados

### Caso de Uso 2: Performance Regional

**Necessidade de Negócio:**
O diretor comercial precisa entender por que a região Sul tem performance inferior às outras.

**Como o DW resolve:**
Hierarquia geográfica permite drill-down progressivo:

```sql
-- Nível 1: Comparar regiões
SELECT 
    r.regiao_pais,
    COUNT(DISTINCT fv.cliente_id) AS clientes_unicos,
    SUM(fv.valor_total_liquido) AS receita,
    AVG(fv.valor_total_liquido) AS ticket_medio
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
GROUP BY r.regiao_pais
ORDER BY receita DESC;

-- Nível 2: Detalhar no Sul - quais estados?
SELECT 
    r.estado,
    r.nome_estado,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
WHERE r.regiao_pais = 'Sul'
GROUP BY r.estado, r.nome_estado
ORDER BY receita DESC;

-- Nível 3: Detalhar no estado - quais cidades?
SELECT 
    r.cidade,
    COUNT(*) AS total_vendas,
    SUM(fv.valor_total_liquido) AS receita
FROM fact.FACT_VENDAS fv
JOIN dim.DIM_REGIAO r ON fv.regiao_id = r.regiao_id
WHERE r.estado = 'RS'
GROUP BY r.cidade
ORDER BY receita DESC;
```

### Caso de Uso 3: Otimização de Mix de Produtos

**Necessidade de Negócio:**
O gerente de produtos precisa decidir quais itens promover e quais descontinuar.

**Como o DW resolve:**
```sql
-- Análise ABC: quais produtos geram 80% da receita?
WITH produto_receita AS (
    SELECT 
        p.categoria,
        p.nome_produto,
        p.nome_fornecedor,
        SUM(fv.valor_total_liquido) AS receita,
        SUM(fv.valor_total_liquido - fv.custo_total) AS lucro,
        SUM(fv.quantidade_vendida) AS qtd_vendida,
        SUM(fv.quantidade_devolvida) AS qtd_devolvida
    FROM fact.FACT_VENDAS fv
    JOIN dim.DIM_PRODUTO p ON fv.produto_id = p.produto_id
    GROUP BY p.categoria, p.nome_produto, p.nome_fornecedor
),
produto_percentual AS (
    SELECT 
        *,
        receita * 100.0 / SUM(receita) OVER () AS perc_receita,
        SUM(receita * 100.0 / SUM(receita) OVER ()) OVER (
            ORDER BY receita DESC
        ) AS perc_acumulado,
        (qtd_devolvida * 100.0 / NULLIF(qtd_vendida, 0)) AS taxa_devolucao
    FROM produto_receita
)
SELECT 
    categoria,
    nome_produto,
    ROUND(receita, 2) AS receita,
    ROUND(lucro, 2) AS lucro,
    ROUND(perc_receita, 2) AS perc_receita,
    ROUND(perc_acumulado, 2) AS perc_acumulado,
    ROUND(taxa_devolucao, 2) AS taxa_devolucao,
    CASE 
        WHEN perc_acumulado <= 80 THEN 'A - Top 80%'
        WHEN perc_acumulado <= 95 THEN 'B - Próximos 15%'
        ELSE 'C - Últimos 5%'
    END AS classificacao_abc
FROM produto_percentual
ORDER BY receita DESC;
```

**Decisões baseadas em dados:**
- Produtos A: Foco em manter estoque e promover
- Produtos B: Monitorar para oportunidades
- Produtos C: Candidatos a descontinuação (especialmente se alta devolução)

### Caso de Uso 4: Efetividade de Campanhas

**Necessidade de Negócio:**
O time de marketing investe milhares em cupons e precisa provar ROI.

**Como o DW resolve:**
```sql
-- Comparar vendas com e sem desconto
WITH vendas_segmentadas AS (
    SELECT 
        CASE WHEN fv.teve_desconto = 1 THEN 'Com Desconto' 
             ELSE 'Sem Desconto' 
        END AS tipo_venda,
        COUNT(*) AS total_vendas,
        AVG(fv.valor_total_liquido) AS ticket_medio,
        AVG(fv.valor_total_liquido - fv.custo_total) AS margem_media,
        SUM(fv.valor_total_liquido) AS receita_total
    FROM fact.FACT_VENDAS fv
    GROUP BY CASE WHEN fv.teve_desconto = 1 THEN 'Com Desconto' 
                  ELSE 'Sem Desconto' END
)
SELECT 
    tipo_venda,
    total_vendas,
    ROUND(ticket_medio, 2) AS ticket_medio,
    ROUND(margem_media, 2) AS margem_media,
    ROUND(receita_total, 2) AS receita_total
FROM vendas_segmentadas;

-- ROI por campanha específica
SELECT 
    d.nome_campanha,
    d.codigo_desconto,
    COUNT(DISTINCT fd.venda_id) AS vendas_impactadas,
    SUM(fd.valor_desconto_aplicado) AS custo_campanha,
    SUM(fd.valor_com_desconto) AS receita_gerada,
    (SUM(fd.valor_com_desconto) / 
     NULLIF(SUM(fd.valor_desconto_aplicado), 0)) AS roi,
    AVG(fd.impacto_margem) AS impacto_medio_margem
FROM fact.FACT_DESCONTOS fd
JOIN dim.DIM_DESCONTO d ON fd.desconto_id = d.desconto_id
GROUP BY d.nome_campanha, d.codigo_desconto
ORDER BY roi DESC;
```

---

## 🔄 Fluxo de Dados

Entender como os dados fluem desde os sistemas fonte até as análises finais é crucial:

### 1. Sistemas Fonte (OLTP)

**Sistema de Vendas (E-commerce):**
- Registra cada pedido conforme cliente compra
- Armazena dados normalizados em múltiplas tabelas
- Otimizado para velocidade de escrita
- Exemplos: Magento, Shopify, VTEX

**Sistema de CRM:**
- Cadastro e histórico de clientes
- Segmentação e campanhas de marketing
- Exemplos: Salesforce, HubSpot

**Sistema ERP:**
- Cadastro de produtos e fornecedores
- Controle de estoque e precificação
- Exemplos: SAP, TOTVS

**Sistema de RH:**
- Cadastro de vendedores e equipes
- Estrutura organizacional e metas
- Exemplos: ADP, Workday

### 2. Extração (ETL - Extract)

Os dados são extraídos dos sistemas fonte periodicamente:

```
Sistemas Fonte → Staging Area (Área de Preparação)

Frequências típicas:
├─ Vendas: Horária ou em tempo real (mudança de dados - CDC)
├─ Produtos: Diária (catálogo muda pouco)
├─ Clientes: Diária
├─ Metas: Mensal (após fechamento)
└─ Estrutura organizacional: Semanal
```

**Staging Area:**
Cópia temporária dos dados exatamente como vieram da fonte, sem transformações. Serve como backup e ponto de restart se algo der errado no processamento.

### 3. Transformação (ETL - Transform)

Os dados são limpos, padronizados e enriquecidos:

**Limpeza:**
- Remover duplicatas
- Corrigir valores nulos
- Padronizar formatos (datas, telefones, CEPs)
- Validar integridade (CPF válido, email válido)

**Enriquecimento:**
- Adicionar dados demográficos (população, PIB) às regiões
- Calcular métricas derivadas (margem, ticket médio)
- Classificar clientes em segmentos
- Geocodificar endereços (latitude/longitude)

**Lookup de Dimensões:**
- Buscar surrogate keys correspondentes aos natural keys
- Criar novos registros em dimensões quando necessário (novos produtos, novos clientes)

### 4. Carga (ETL - Load)

Dados transformados são inseridos no DW:

**Dimensões primeiro:**
```
1. DIM_DATA (pré-povoada)
2. DIM_PRODUTO (produtos novos)
3. DIM_CLIENTE (clientes novos)
4. DIM_REGIAO (raramente muda)
5. DIM_EQUIPE (mudanças organizacionais)
6. DIM_VENDEDOR (novos vendedores)
7. DIM_DESCONTO (novas campanhas)
```

**Facts depois:**
```
1. FACT_VENDAS (vendas do período)
2. FACT_DESCONTOS (descontos aplicados)
3. FACT_METAS (fechamento mensal)
```

**Padrões de carga:**
- **Full Load:** Carga completa (apenas dimensões pequenas ou setup inicial)
- **Incremental Load:** Apenas dados novos ou modificados (padrão para facts)
- **Upsert:** Insert se novo, Update se existente (dimensões)

### 5. Análise e Consumo

Dados prontos para uso:

**Ferramentas de BI:**
- Power BI, Tableau, Looker conectam diretamente ao DW
- Relatórios e dashboards pré-construídos
- Análises ad-hoc pelos usuários

**Aplicações Analytics:**
- Machine Learning para previsões
- Modelos estatísticos para otimização
- APIs para integração com outros sistemas

**Consultas SQL Diretas:**
- Analistas experientes escrevem queries customizadas
- Extração de dados para planilhas e apresentações

### Diagrama Completo do Fluxo

```
┌─────────────────────────────────────────────────────────────────┐
│                    SISTEMAS FONTE (OLTP)                        │
├──────────────┬──────────────┬──────────────┬──────────────────┤
│  E-commerce  │     CRM      │     ERP      │        RH        │
│   (Vendas)   │  (Clientes)  │  (Produtos)  │  (Vendedores)   │
└──────┬───────┴──────┬───────┴──────┬───────┴────────┬─────────┘
       │              │              │                │
       │              │              │                │
       ▼              ▼              ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      STAGING AREA                                │
│             (Cópia temporária sem transformações)                │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PROCESSO ETL                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. Limpeza: remover erros e inconsistências                    │
│  2. Padronização: formatos uniformes                            │
│  3. Enriquecimento: adicionar dados calculados/externos         │
│  4. Lookup: converter natural keys → surrogate keys             │
│  5. Validação: garantir integridade referencial                 │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                DATA WAREHOUSE (Star Schema)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│         DIM_DATA    DIM_CLIENTE    DIM_PRODUTO                  │
│              \          |            /                           │
│               \         |           /                            │
│                └─── FACT_VENDAS ──┘                             │
│                        |                                         │
│                   DIM_REGIAO                                     │
│                                                                  │
│         FACT_METAS ←→ DIM_VENDEDOR ←→ DIM_EQUIPE               │
│                                                                  │
│         FACT_DESCONTOS ←→ DIM_DESCONTO                          │
│                                                                  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CAMADA DE CONSUMO                              │
├──────────────┬──────────────┬──────────────┬──────────────────┤
│   Power BI   │   Tableau    │  Looker      │   SQL Direto    │
│  (Dashboards)│ (Relatórios) │  (Analytics) │   (Analistas)   │
└──────────────┴──────────────┴──────────────┴──────────────────┘
```

---

## 📚 Conclusão e Próximos Passos

Este Data Warehouse representa uma base sólida para análises de e-commerce, seguindo boas práticas de modelagem dimensional e a metodologia Kimball. A arquitetura Star Schema oferece o equilíbrio ideal entre performance, simplicidade e flexibilidade analítica.

### O que foi Construído

✅ **7 Dimensões completas** - cobrindo tempo, clientes, produtos, geografia e organização de vendas  
✅ **3 Tabelas Fato** - capturando vendas transacionais, metas periódicas e eventos de desconto  
✅ **Hierarquias naturais** - permitindo drill-down e roll-up intuitivos  
✅ **Granularidade otimizada** - máximo detalhe sem complexidade desnecessária  
✅ **Relacionamentos claros** - Star Schema puro com algumas extensões justificadas  

### Capacidades Analíticas

O modelo suporta análises em várias dimensões:

**Temporal:** tendências, sazonalidade, comparações year-over-year  
**Geográfica:** performance regional, penetração de mercado, correlações demográficas  
**Produto:** mix de produtos, análise ABC, margem por categoria  
**Cliente:** segmentação, lifetime value, padrões de compra  
**Vendas:** performance individual, atingimento de metas, rankings  
**Campanhas:** ROI de descontos, impacto na margem, efetividade promocional  

### Próximas Expansões Possíveis

**Dimensões adicionais:**
- DIM_CANAL (loja física, e-commerce, marketplace, televendas)
- DIM_FORMA_PAGAMENTO (cartão, boleto, PIX, parcelamento)
- DIM_CAMPANHA_MARKETING (origem do cliente, campanha de aquisição)
- DIM_FORNECEDOR (separar de DIM_PRODUTO para análises mais profundas)

**Facts adicionais:**
- FACT_ESTOQUE (movimentações, inventário)
- FACT_LOGISTICA (envios, entregas, prazos)
- FACT_ATENDIMENTO (tickets de suporte, satisfação)
- FACT_PAGAMENTOS (transações financeiras detalhadas)

**Melhorias técnicas:**
- Implementar SCD Type 2 para dimensões críticas (clientes, produtos)
- Aggregate tables para queries muito frequentes
- Particionamento de facts por data
- Implementação de data quality checks automatizados

### Documentação Relacionada

Para aprofundar seu conhecimento sobre este DW:

📖 **[Dimensões Detalhadas](02_dimensoes.md)** - Especificação completa de cada dimensão  
📖 **[Tabelas Fato](03_fatos.md)** - Detalhamento de métricas e análises  
📖 **[Relacionamentos](04_relacionamentos.md)** - Mapa de foreign keys e integridade  
📖 **[Decisões de Design](../decisoes/01_decisoes_modelagem.md)** - Justificativas das escolhas  
📖 **[Dicionário de Dados](05_dicionario_dados.md)** - Catálogo completo de campos  
📖 **[Queries de Exemplo](../queries/README.md)** - 22 exemplos práticos de análises  

---

<div align="center">

**[⬆ Voltar ao topo](#-visão-geral-da-modelagem)**

*Modelagem dimensional baseada na metodologia Kimball*  
*Desenvolvido para máxima performance analítica e facilidade de uso*

</div>