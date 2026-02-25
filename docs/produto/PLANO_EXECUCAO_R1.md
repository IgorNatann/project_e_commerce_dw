# Plano de Execucao R1 - Plataforma de Analytics E-commerce

Versao: 1.0  
Data: 2026-02-25  
Base: PRD v1.0 (`docs/produto/PRD.md`)

## 1. Objetivo deste plano

Transformar o projeto atual em produto operacional de dados, com carga incremental diaria, qualidade automatizada e consumo via dashboards.

## 2. Premissas de execucao

- Janela alvo de entrega: 7 semanas.
- Cadencia: 1 sprint por semana.
- Time minimo: 1 engenharia de dados + 1 analista BI + 1 PO.
- Ambiente minimo: SQL Server para DEV e HML.
- Escopo R1: foco em P0 do PRD.

## 3. Cronograma macro

| Sprint | Duracao | Objetivo principal | Gate de saida |
|---|---:|---|---|
| S0 | 1 semana | Alinhamento de contrato de produto e setup de trabalho | KPIs e ownership aprovados |
| S1 | 1 semana | OLTP funcional (estrutura core) | DDL OLTP executando sem erro |
| S2 | 1 semana | Seeds e validacoes OLTP para extracao incremental | Cenarios base e incremental validos |
| S3 | 1 semana | ETL incremental de dimensoes | Dimensoes carregando por watermark |
| S4 | 1 semana | ETL incremental de fatos + idempotencia | Fatos estaveis e sem duplicidade |
| S5 | 1 semana | Qualidade automatizada e observabilidade | Suite de testes e alertas ativos |
| S6 | 1 semana | Dashboards, homologacao e go-live R1 | Go/No-Go aprovado |

## 4. Backlog por sprint

### S0 - Alinhamento e contrato

Objetivo: fechar o que sera entregue no R1 e como sera medido.

Escopo:
- Congelar definicoes de KPI e granularidade.
- Definir dono por requisito (RACI simples).
- Definir ferramenta de BI oficial.
- Definir SLA de carga diario.
- Criar board de execucao (colunas: Todo, Doing, Review, Done).

Entregaveis:
- Documento de metricas v1 aprovado.
- Matriz de responsabilidades.
- Criterio de Go/No-Go final alinhado.

Criterios de aceite:
- Todos os KPIs de negocio do PRD com formula e fonte.
- Responsavel definido para cada RF-01 a RF-16.
- Aprovacao formal do PO.

### S1 - OLTP core funcional

Objetivo: remover placeholders da camada OLTP.

Escopo tecnico:
- Implementar tabelas core no arquivo `sql/oltp/01_ddl/01_create_tables_core.sql`.
- Revisar scripts de setup OLTP para execucao limpa.
- Garantir PK, FK e `updated_at` em tabelas fonte.
- Criar indices basicos para extracao incremental.

Entregaveis:
- DDL OLTP completo e executavel.
- Script de criacao de banco/schema revisado.
- Readme OLTP atualizado com ordem de execucao.

Criterios de aceite:
- `00_setup -> 01_ddl` executa sem erro em ambiente limpo.
- Tabelas core criadas com constraints minimas.
- Nao existe mais `TODO` nos scripts de setup/DDL do OLTP.

### S2 - Seeds e validacoes de extracao

Objetivo: preparar dados fonte confiaveis para ETL incremental.

Escopo tecnico:
- Implementar `sql/oltp/02_seed/01_seed_base.sql`.
- Implementar `sql/oltp/02_seed/02_seed_incremental.sql`.
- Implementar `sql/oltp/99_validation/01_checks.sql`.
- Simular inserts/updates deterministas por timestamp.

Entregaveis:
- Seed base com dados coerentes.
- Seed incremental com cenarios de mudanca.
- Script de checks de qualidade no OLTP.

Criterios de aceite:
- Carga base gera volume esperado por tabela.
- Carga incremental altera somente registros alvo.
- Checks retornam status de qualidade sem falhas bloqueantes.

### S3 - ETL incremental de dimensoes

Objetivo: carregar dimensoes do DW com estrategia incremental.

Escopo tecnico:
- Implementar base de ETL em `python/etl/` (extract, transform, load).
- Criar controle de watermark por entidade.
- Implementar upsert para dimensoes.
- Registrar auditoria de execucao (inicio, fim, status, volume).

Entregaveis:
- Pipeline de dimensoes executavel por comando unico.
- Tabela de controle de watermark.
- Log de execucao da carga.

Criterios de aceite:
- Executar duas vezes seguidas sem duplicar dimensoes.
- Novos registros no OLTP aparecem no DW apos reprocesso.
- Log de execucao persistido com resultado.

### S4 - ETL incremental de fatos

Objetivo: carregar fatos de forma consistente e idempotente.

Escopo tecnico:
- Implementar carga incremental de `FACT_VENDAS`, `FACT_METAS`, `FACT_DESCONTOS`.
- Tratar dependencia entre fatos (ordem de carga).
- Garantir integridade referencial com dimensoes.
- Implementar estrategia de retry e rollback seguro.

Entregaveis:
- Pipeline de fatos acoplado ao pipeline de dimensoes.
- Reprocessamento de periodo sem duplicidade.
- Relatorio de volumes por execucao.

Criterios de aceite:
- Reexecucao do mesmo lote nao altera contagens indevidamente.
- Nao ha orfaos nas FKs obrigatorias.
- Tempo de carga dentro da janela definida para HML.

### S5 - Qualidade, testes e observabilidade

Objetivo: tornar a operacao previsivel e confiavel.

Escopo tecnico:
- Criar suite automatizada de testes SQL (smoke + regras de negocio).
- Criar testes Python para funcoes criticas de ETL.
- Integrar validacao em pipeline CI.
- Configurar alertas de falha de execucao.

Entregaveis:
- Pacote de testes automatizados versionado.
- Job de CI executando testes em merge.
- Alertas basicos de falha (email/chat).

Criterios de aceite:
- Testes rodam automatico em pipeline.
- Falha de qualidade bloqueia promocao para proxima etapa.
- Alertas entregues com contexto minimo (job, horario, erro).

### S6 - Dashboards e rollout R1

Objetivo: entregar valor para negocio e entrar em operacao.

Escopo tecnico:
- Construir dashboards R1 (vendas, metas, descontos/ROI).
- Validar indicadores com stakeholders.
- Executar UAT e checklist de Go/No-Go.
- Publicar runbook operacional e plano de incidentes.

Entregaveis:
- Dashboards publicados em ambiente de consumo.
- UAT assinado por negocio.
- Runbook de operacao e recuperacao.

Criterios de aceite:
- KPIs batem com consultas SQL de referencia.
- Go/No-Go aprovado com CA-01 a CA-05 do PRD.
- Time de negocio apto a usar sem apoio tecnico continuo.

## 5. Sequenciamento tecnico recomendado

Ordem de implementacao:

1. OLTP (estrutura, seeds, checks).  
2. ETL dimensoes (watermark + upsert).  
3. ETL fatos (idempotencia + integridade).  
4. Testes automatizados e observabilidade.  
5. Dashboards e rollout.

## 6. Quadro de controle por sprint

Use o quadro abaixo no inicio e no fim de cada sprint:

| Item | Meta da sprint | Resultado real | Status |
|---|---|---|---|
| Escopo planejado concluido | >= 90% |  |  |
| Defeitos bloqueantes abertos | 0 |  |  |
| Testes automatizados passando | 100% dos testes da sprint |  |  |
| Documentacao atualizada | Sim |  |  |
| Gate de saida cumprido | Sim |  |  |

## 7. Riscos praticos por fase

| Fase | Risco | Mitigacao |
|---|---|---|
| S1-S2 | Modelo OLTP sem campo de controle incremental | Padronizar `updated_at` e PK em todas tabelas fonte |
| S3 | Upsert inconsistente nas dimensoes | Testes de reprocessamento com mesma janela |
| S4 | Duplicidade em fatos | Chaves tecnicas e idempotencia por lote |
| S5 | Falsa sensacao de qualidade | Cobrir checks de negocio e referencial, nao apenas smoke |
| S6 | KPI divergente no dashboard | Dataset certificado e query de referencia por KPI |

## 8. Definicao de pronto por sprint

Cada sprint so encerra quando:

- Codigo versionado e revisado.
- Criterios de aceite da sprint atendidos.
- Evidencias registradas (prints, logs, query de validacao).
- Documentacao atualizada no repositorio.

## 9. Primeiros 5 passos (acao imediata)

1. Validar este plano com PO e negocio (S0).  
2. Escolher ferramenta de BI oficial do R1.  
3. Abrir tasks de S1 para remover TODO do OLTP.  
4. Definir formato padrao de watermark e log de ETL.  
5. Agendar review semanal fixa de status e riscos.
