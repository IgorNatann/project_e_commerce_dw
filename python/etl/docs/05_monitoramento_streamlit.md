# Monitoramento ETL com Streamlit

Este dashboard mostra o estado do ETL em tempo quase real usando:

- `ctl.etl_control`
- `audit.etl_run`
- `audit.etl_run_entity`
- `audit.connection_login_events`
- `dim.DIM_CLIENTE` (saude do alvo)
- `dim.DIM_PRODUTO` (saude do alvo)
- `core.customers` (amostra da origem)
- `core.products` (amostra da origem)

## 1) Pre-requisitos

1. Stack Docker ativa (recomendado):

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

2. Dependencias locais (somente se for rodar Streamlit fora do container):

```powershell
pip install -r python/etl/monitoring/requirements.txt
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
streamlit run python/etl/monitoring/app.py
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
   - cobertura `dim_cliente` e `dim_produto` (`target_total/source_total`)
   - pendencia incremental total (registros apos watermark)
   - latencia por entidade (diferenca entre `source_max_updated_at` e `target_max_updated_at`)
   - throughput medio (linhas por segundo) nas execucoes com sucesso (24h)
3. Saude por pipeline:
   - seletor dinamico para qualquer entidade/fato cadastrado em `ctl.etl_control`
   - metricas de cobertura, pendencia incremental, latencia, duracao e throughput
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
9. Grade de falhas recentes com mensagem de erro.
10. Bloco de execucao em andamento (`status = running`) para run e entidade.

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
4. `dim_cliente ativa = OK`
5. sem erro no bloco de pre-flight

## 7) Blocos adicionais (escopo atual)

1. **Saude por pipeline**
   - suporte dinamico para entidade/fato
   - volume fonte vs alvo
   - watermark atual da entidade selecionada
   - checks de integridade basica e auditoria da ultima execucao
   - amostra recente da origem correspondente
2. **Auditoria de conexoes SQL**
   - eventos por hora (24h)
   - top logins (24h)
   - tabela de eventos recentes de conexao
