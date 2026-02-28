# Monitoramento ETL com Streamlit

Este dashboard mostra o estado do ETL em tempo quase real usando:

- `ctl.etl_control`
- `audit.etl_run`
- `audit.etl_run_entity`
- `audit.connection_login_events`
- `dim.DIM_CLIENTE` (saude do alvo)
- `dim.DIM_PRODUTO` (saude do alvo)
- `dim.DIM_REGIAO` (saude do alvo)
- `dim.DIM_DESCONTO` (saude do alvo)
- `core.customers` (amostra da origem)
- `core.products` (amostra da origem)
- `core.regions` (amostra da origem)
- `core.discount_campaigns` (amostra da origem)

## 1) Pre-requisitos

1. Stack Docker ativa (recomendado):

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

2. Dependencias locais (somente se for rodar Streamlit fora do container):

```powershell
pip install -r dashboards/streamlit/monitoring/requirements.txt
```

3. Variaveis de ambiente (somente modo local):

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 18 for SQL Server"
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
$env:ETL_SQL_USER = "etl_monitor"
$env:ETL_SQL_PASSWORD = "<senha de MSSQL_MONITOR_PASSWORD>"
$env:ETL_DW_DB = "DW_ECOMMERCE"
$env:ETL_OLTP_DB = "ECOMMERCE_OLTP"
```

> Observacao: o app aceita `ODBC Driver 18` ou `17`.

## 2) Executar dashboard

Via Docker (ja sobe automaticamente no `up_stack.ps1`):

- `http://localhost:8501`

Via local:

```powershell
streamlit run dashboards/streamlit/monitoring/app.py
```

## 3) O que voce acompanha

Navegacao lateral por paginas:

- `Resumo operacional`
- `Saude por pipeline`
- `Runs e controle`
- `Auditoria de conexoes`

Em todas as paginas o bloco de **Pre-flight** fica no topo para validar readiness.

1. Cards de resumo:
   - entidades ativas
   - taxa de sucesso de runs (24h)
   - falhas de run (24h)
   - status do ultimo run
2. KPIs `OLTP -> DW`:
   - cobertura por entidade ativa (`target_total/source_total`)
   - pendencia incremental total (registros apos watermark)
   - latencia por entidade (diferenca entre `source_max_updated_at` e `target_max_updated_at`)
   - throughput medio (linhas por segundo) nas execucoes com sucesso (24h)
3. Saude por pipeline:
   - seletor dinamico para qualquer entidade/fato cadastrado em `ctl.etl_control`
   - metricas de cobertura, pendencia incremental, latencia, duracao e throughput
   - painel generico de qualidade/reconciliacao por check
   - checks automaticos: nulos de chave, duplicidade de chave natural, status invalido e soft delete
   - amostra recente da origem do pipeline selecionado
4. Contexto geral dos pipelines:
   - status por entidade (`OK`, `FALHA`, `RODANDO`, `PENDENTE_ESTRUTURA`, `SEM_EXECUCAO`)
   - ultima execucao da entidade (extraidos/upsertados/erros)
   - matriz operacional com `source_total`, `target_total`, `coverage_percent`
   - pendencia incremental por watermark (`source_pending_since_watermark`)
   - latencia (`freshness_minutes`) e performance (`entity_last_duration_seconds`, `entity_last_throughput_rows_per_sec`)
   - existencia de fonte/alvo por pipeline
5. Tabela de controle incremental (`ctl.etl_control`).
6. Tabela dos ultimos runs (`audit.etl_run`).
7. Detalhe por entidade de um `run_id` selecionado.
8. Graficos:
   - runs por status (14 dias)
   - volume extraido/upsertado por entidade (14 dias)
9. Timeline de execucao:
   - visualizacao temporal por `run_id` e `entity_name`
   - barra com inicio/fim/status da execucao
   - tabela de apoio com duracao e volumes da entidade
10. Grade de falhas recentes com mensagem de erro.
11. Bloco de execucao em andamento (`status = running`) para run e entidade.
12. Alertas e SLA:
   - taxa de sucesso em 24h e 7 dias
   - conformidade SLA por entidades ativas
   - alertas de atraso de watermark, sem execucao recente e falha recorrente
13. Auditoria tecnica consolidada:
    - filtros por janela, login, programa, base e status
    - correlacao temporal entre eventos de conexao e falhas ETL
    - taxonomia de erros ETL por tipo com motivo rapido e acao sugerida
    - grade de falhas ETL recentes com assinatura tecnica para troubleshooting rapido
    - bloco dedicado de extracao OLTP (`ECOMMERCE_OLTP`) com filtros tecnicos por login, programa e host

## 4) Uso recomendado

1. Abra o dashboard e valide o bloco **Pre-flight de monitoramento**.
2. Garanta status `Dim Cliente pronta = OK`.
3. Rode o ETL (`run_etl.py`).
4. Atualize o dashboard no botao `Atualizar agora`.
5. Em caso de falha:
   - filtre o `run_id`
   - veja `error_message` por entidade
   - confira se watermark ficou parado em `ctl.etl_control`.

## 5) Acompanhamento em tempo real

1. Deixe o `Auto-refresh` ligado.
2. Ajuste o intervalo (ex.: 5 ou 10 segundos).
3. Execute o ETL em outro terminal.
4. Acompanhe o bloco `Execucao em andamento agora`.

## 6) Checklist rapido antes do primeiro run

1. `Conexao DW = OK`
2. `Conexao OLTP = OK`
3. `Dim Cliente pronta = OK`
4. `pelo menos 1 entidade ativa = OK`
5. sem erro no bloco de pre-flight

## 7) Blocos adicionais (escopo atual)

1. **Saude por pipeline**
   - suporte dinamico para entidade/fato
   - volume fonte vs alvo
   - watermark atual da entidade selecionada
   - checks genericos de qualidade e reconciliacao por pipeline
   - resumo de checks em `OK`, `ATENCAO` e `ALERTA`
   - amostra recente da origem correspondente
2. **Auditoria de conexoes SQL**
    - eventos por hora (24h)
    - top logins (24h)
    - consolidacao tecnica com programas, bases, status e filtros
    - filtro dedicado para extracao OLTP por login/programa/host
    - correlacao de conexoes com falhas ETL
    - taxonomia e detalhe de erros ETL recentes
