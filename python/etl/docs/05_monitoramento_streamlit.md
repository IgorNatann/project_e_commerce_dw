# Monitoramento ETL com Streamlit

Este dashboard mostra o estado do ETL em tempo quase real usando:

- `ctl.etl_control`
- `audit.etl_run`
- `audit.etl_run_entity`

## 1) Pre-requisitos

1. Dependencias instaladas:

```powershell
pip install -r python/requirements.txt
```

2. Variaveis de ambiente do DW configuradas (mesmas do ETL):

```powershell
$env:ETL_DW_CONN_STR = "Driver={ODBC Driver 17 for SQL Server};Server=localhost,1433;Database=DW_ECOMMERCE;Trusted_Connection=yes;TrustServerCertificate=yes;"
```

Ou usando variaveis separadas:

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 17 for SQL Server"
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
$env:ETL_DW_DB = "DW_ECOMMERCE"
```

> Observacao: o app aceita `ODBC Driver 18` ou `17`. Se `ETL_SQL_DRIVER` nao for informado, ele tenta detectar automaticamente.

## 2) Executar dashboard

```powershell
streamlit run python/etl/monitoring/app.py
```

## 3) O que voce acompanha

1. Cards de resumo:
   - entidades ativas
   - falhas nas ultimas 24h
   - ultimo `run_id`
   - status do ultimo run
2. Tabela de controle incremental (`ctl.etl_control`).
3. Tabela dos ultimos runs (`audit.etl_run`).
4. Detalhe por entidade de um `run_id` selecionado.
5. Graficos:
   - runs por status (14 dias)
   - volume extraido/upsertado por entidade (14 dias)
6. Grade de falhas recentes com mensagem de erro.
7. Bloco de execucao em andamento (`status = running`) para run e entidade.

## 4) Uso recomendado

1. Abra o dashboard e valide o bloco **Pre-flight de monitoramento**.
2. Garanta status `Pronto para 1o run = OK`.
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
2. `Objetos monitoria = OK`
3. `Pronto para 1o run = OK`
4. `entities ativas > 0` em `ctl.etl_control`
5. sem erro no bloco de pre-flight
