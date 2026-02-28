# PRD - Plataforma de Analytics para E-commerce (DW)

Versao: 1.2  
Data: 2026-02-28  
Status: Atualizado com baseline real do repositorio

## 1. Resumo executivo

Este produto cria uma plataforma de analytics para e-commerce baseada em SQL Server, modelagem dimensional (Kimball) e camada de consumo para decisao comercial.

O repositorio ja possui operacao ponta a ponta em ambiente Docker para o escopo inicial: camada OLTP funcional, ETL incremental em Python, auditoria tecnica e dashboards Streamlit (monitor ETL e vendas R1).

Este PRD consolida o estado atual e define o que ainda precisa ser entregue para evoluir de escopo inicial validado para produto de dados operacional completo para negocio.

## 2. Problema

Hoje, times de negocio e analise nao tem uma plataforma unica, confiavel e padronizada para responder perguntas como:

- Qual receita liquida por periodo, regiao, categoria e vendedor?
- Qual taxa de atingimento de metas por vendedor e equipe?
- Qual ROI de campanhas e impacto real de descontos na margem?

Sem uma plataforma operacional:

- analises ficam manuais e lentas
- metricas podem divergir entre areas
- decisao comercial perde velocidade e confiabilidade

## 3. Visao do produto

Entregar uma plataforma de dados analiticos que permita:

- consolidar dados de vendas, metas e descontos em um DW confiavel
- disponibilizar metricas padronizadas para consumo por SQL e dashboards
- garantir qualidade, rastreabilidade e operacao recorrente (nao apenas carga manual)

## 4. Objetivos

### 4.1 Objetivos de negocio

- Reduzir tempo de resposta para perguntas analiticas de dias para horas/minutos.
- Padronizar definicao de KPIs comerciais entre times.
- Aumentar capacidade de decisao baseada em dados em vendas, marketing e lideranca.

### 4.2 Objetivos de produto

- Operar pipeline incremental OLTP -> Staging -> DW diariamente.
- Disponibilizar camada de consumo com views estaveis e dashboards priorizados.
- Garantir monitoramento e testes de qualidade de dados.

### 4.3 Nao objetivos (agora)

- Predicao com ML em producao.
- Streaming em tempo real.
- Data lake multi-plataforma.
- Camada financeira/contabil completa alem do escopo comercial.

## 5. Escopo

### 5.1 Escopo MVP (release R1)

- OLTP funcional minimo para simulacao realista de extracao incremental.
- Pipeline ETL incremental com watermark e idempotencia.
- Carga de dimensoes e fatos principais no DW:
  - DIM_DATA, DIM_CLIENTE, DIM_PRODUTO, DIM_REGIAO, DIM_EQUIPE, DIM_VENDEDOR, DIM_DESCONTO
  - FACT_VENDAS, FACT_METAS, FACT_DESCONTOS
- Suite minima de testes automatizados de qualidade e regressao.
- Dashboards iniciais para:
  - vendas e margem
  - metas e atingimento
  - descontos e ROI
- Documentacao operacional de execucao, incidentes e recuperacao.

### 5.2 Escopo pos-MVP (R2+)

- SCD Type 2 para dimensoes criticas.
- Otimizacoes avancadas (particionamento, agregacoes, possivel columnstore).
- Dashboards adicionais por canal/logistica/estoque.

## 6. Stakeholders e usuarios

### 6.1 Stakeholders

- Product Owner de dados (dono do backlog e prioridades).
- Lideranca comercial (diretores/gerentes de vendas).
- Marketing (gestao de campanhas e descontos).
- Engenharia de dados (implementacao e operacao).

### 6.2 Perfis de usuario

- Analista de BI: explora dados e cria relatorios.
- Gerente comercial: acompanha meta, ranking e performance regional.
- Marketing: avalia uso de cupom, receita incremental e impacto de margem.
- Engenharia de dados: garante carga, qualidade e disponibilidade.

## 7. Estado atual (as-is)

### 7.1 Ja implementado

- Infra one-shot com Docker Compose para SQL Server, bootstrap SQL e apps Streamlit.
- Camada OLTP funcional (`ECOMMERCE_OLTP`) com setup, DDL e seed base/incremental.
- Camada DW (`DW_ECOMMERCE`) com setup, DDL dimensional (7 dimensoes e 3 fatos), views auxiliares e seguranca de leitura (`bi_reader`).
- Controle ETL e auditoria tecnica ativos (`ctl.etl_control`, `audit.etl_run`, `audit.etl_run_entity`, `audit.connection_login_events`).
- ETL incremental Python implementado para `dim_cliente`, `dim_produto`, `dim_regiao`, `dim_vendedor`, `dim_equipe`, `dim_desconto`, `fact_vendas`, `fact_metas` e `fact_descontos`.
- Dashboard tecnico de monitoramento ETL publicado (`:8501`) e dashboard de vendas R1 publicado (`:8502`).
- Documentacao tecnica ampla (modelagem, contratos, queries e evolucao diaria/mensal/marcos).

### 7.2 Lacunas criticas

- Suite automatizada de validacao ponta a ponta ainda nao consolidada (integridade, regressao e smoke diario).
- Carga de fatos ja implementada, porem ainda sem consolidacao operacional completa (quality gates, smoke diario e evidencias recorrentes).
- Dashboards de metas/atingimento e descontos/ROI ainda nao publicados.
- Alertas automatizados externos para falhas de pipeline ainda nao implementados.
- Runbook operacional formal de rotina, incidente e recuperacao ainda incompleto.

### 7.3 Fonte oficial de acompanhamento

- Estado de produto e lacunas: este PRD (secoes 7, 13 e 17).
- Plano de execucao da semana: `docs/produto/PLANO_FECHAMENTO_PORTFOLIO_MVP.md`.
- Snapshot historico por data: `docs/status_reports/`.

## 8. Jornadas principais

### Jornada 1 - Gerente comercial

- Abre dashboard de performance mensal.
- Compara realizado vs meta por equipe/vendedor.
- Identifica desvios e aciona plano de recuperacao.

### Jornada 2 - Marketing

- Analisa cupons/campanhas por uso e ROI.
- Compara vendas com e sem desconto.
- Ajusta estrategia para preservar margem.

### Jornada 3 - Analista BI

- Executa consultas ad-hoc sobre views padronizadas.
- Cruza periodo, produto, regiao e vendedor.
- Publica relatorio recorrente sem retrabalho manual de joins.

## 9. Requisitos funcionais (RF)

### 9.1 Fonte e extracao

- RF-01: Implementar schema OLTP com tabelas operacionais minimas (`customers`, `products`, `orders`, `order_items`, `discounts`, `sellers`).
- RF-02: Popular OLTP com seed base e seed incremental deterministico.
- RF-03: Disponibilizar metadados para extracao incremental (`updated_at`, chave primaria, watermark).

### 9.2 ETL e carga

- RF-04: Implementar pipeline incremental para dimensoes com estrategia de upsert.
- RF-05: Implementar pipeline incremental para fatos preservando granularidade definida.
- RF-06: Garantir idempotencia (reprocessar periodo sem duplicar dados).
- RF-07: Registrar auditoria de execucao (inicio, fim, status, volume, erro).

### 9.3 Camada analitica

- RF-08: Manter contratos de modelo dimensional (schemas `dim` e `fact`) com constraints e integridade referencial.
- RF-09: Manter e versionar views auxiliares para consumo.
- RF-10: Publicar queries padrao para KPIs principais.

### 9.4 Consumo e visualizacao

- RF-11: Entregar dashboards executivos de vendas, metas e descontos.
- RF-12: Permitir filtros por periodo, regiao, categoria, equipe e vendedor.
- RF-13: Expor dicionario de metricas para leitura pelos usuarios.

### 9.5 Qualidade e operacao

- RF-14: Implementar testes automatizados de integridade referencial e regras de negocio.
- RF-15: Implementar smoke test diario apos carga.
- RF-16: Implementar mecanismo de alerta em falha de pipeline.

## 10. Requisitos nao funcionais (RNF)

- RNF-01 (Confiabilidade): taxa de sucesso diaria da pipeline >= 99% no periodo mensal.
- RNF-02 (Atualizacao): dados do dia D disponiveis ate D+1 08:00 (horario local).
- RNF-03 (Performance SQL): consultas padrao em views principais <= 10s no volume alvo R1.
- RNF-04 (Qualidade): 0 orfaos em fatos para FKs obrigatorias.
- RNF-05 (Auditabilidade): toda execucao de ETL deve gerar log estruturado.
- RNF-06 (Seguranca): acesso somente leitura para consumidores BI; escrita restrita ao ETL.
- RNF-07 (Versionamento): scripts SQL e jobs ETL versionados em Git com historico de release.
- RNF-08 (Documentacao): runbook e dicionario atualizados a cada release.

## 11. KPIs de produto e definicoes

### 11.1 KPIs de negocio

- Receita liquida: `SUM(valor_total_liquido)`.
- Margem bruta: `SUM(valor_total_liquido - custo_total)`.
- Percentual de atingimento de meta: `(valor_realizado / valor_meta) * 100`.
- ROI de desconto/campanha: `SUM(valor_com_desconto) / SUM(valor_desconto_aplicado)`.
- Taxa de devolucao: `SUM(quantidade_devolvida) / SUM(quantidade_vendida)`.

### 11.2 KPIs operacionais

- SLA de carga diaria cumprido (% de dias).
- Tempo medio de execucao do ETL.
- Taxa de falha por job.
- Numero de incidentes de qualidade por mes.

## 12. Criterios de aceite (Go/No-Go R1)

- CA-01: pipeline incremental executa de ponta a ponta sem intervencao manual por 10 dias uteis consecutivos.
- CA-02: suite de testes de qualidade passa com 100% em ambiente de homologacao.
- CA-03: dashboards R1 publicados e validados por stakeholders de vendas e marketing.
- CA-04: runbook operacional validado com simulacao de falha e recuperacao.
- CA-05: documentacao de metricas aprovada pelo PO e lideranca comercial.

## 13. Roadmap sugerido

### Fase 0 - Alinhamento e contrato (1 semana)

- Concluida: escopo R1 inicial, base de KPIs e granularidade definida para vendas.

### Fase 1 - Fundacao operacional (2 a 3 semanas)

- Concluida: OLTP funcional, DW base, ETL incremental inicial e monitoramento tecnico.

### Fase 2 - Fatos e qualidade (2 a 3 semanas)

- Em andamento: consolidar qualidade operacional de fatos (`fact_metas`, `fact_descontos`) com testes automatizados e evidencias recorrentes.

### Fase 3 - Consumo e rollout (1 a 2 semanas)

- Em andamento: expandir camada de consumo para metas/descontos e formalizar homologacao operacional com negocio.

## 14. Dependencias

- Ambiente SQL Server disponivel para DEV/HML/PRD.
- Definicao de ownership (PO de dados e engenharia responsavel).
- Ferramenta de orquestracao/execucao (ex.: agendador local ou pipeline CI/CD).
- Decisao de ferramenta para pos-MVP (MVP atual usa Streamlit).

## 15. Riscos e mitigacao

- Risco-01: divergencia de definicao de KPI entre areas.
  - Mitigacao: dicionario de metricas aprovado antes da Fase 2.

- Risco-02: ETL sem idempotencia causar duplicidade.
  - Mitigacao: testes de reprocessamento e chaves unicas de controle.

- Risco-03: crescimento de dados degradar consultas.
  - Mitigacao: plano de indexacao e revisao de performance por release.

- Risco-04: dependencia de dados de origem incompletos.
  - Mitigacao: checks de qualidade na camada OLTP/staging com bloqueio de carga invalida.

## 16. Open questions

- O produto tera ambiente de producao dedicado ou operacao local/educacional no curto prazo?
- Manter Streamlit como camada oficial de visualizacao no MVP ou migrar parte do consumo para BI dedicado no pos-MVP?
- Qual frequencia de carga e SLA final esperado pelo negocio (diario, intra-dia)?
- Quais usuarios terao permissao de escrita em estruturas analiticas?

## 17. Backlog inicial priorizado (P0/P1)

### P0

- P0-01: Consolidar suite automatizada de testes (integridade, regressao, smoke diario).
- P0-02: Consolidar validacao operacional de `fact_metas` e `fact_descontos` (smoke, reconciliacao e evidencias de execucao).
- P0-03: Publicar dashboards R1 pendentes (metas/atingimento e descontos/ROI).
- P0-04: Implementar alertas automatizados para falha de pipeline e atraso de SLA.
- P0-05: Formalizar runbook de operacao, incidente e recuperacao.

### P1

- P1-01: Automatizar geracao de documentacao de metricas.
- P1-02: Melhorar observabilidade (metricas de job e alertas detalhados).
- P1-03: Planejar evolucao para SCD Type 2 em dimensoes selecionadas.

## 18. Definicao de pronto (DoD)

Uma entrega sera considerada pronta quando:

- codigo versionado e revisado
- testes automatizados passando
- documentacao atualizada
- validacao funcional com stakeholder responsavel
- monitoramento e log operacional ativos

