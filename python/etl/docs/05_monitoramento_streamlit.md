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
$env:ETL_DW_CONN_STR = "Driver={ODBC Driver 18 for SQL Server};Server=localhost,1433;Database=DW_ECOMMERCE;Trusted_Connection=yes;TrustServerCertificate=yes;"
```

Ou usando variaveis separadas:

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 18 for SQL Server"
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
$env:ETL_DW_DB = "DW_ECOMMERCE"
```

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

## 4) Uso recomendado

1. Rode o ETL (`run_etl.py`).
2. Atualize o dashboard no botao `Atualizar agora`.
3. Em caso de falha:
   - filtre o `run_id`
   - veja `error_message` por entidade
   - confira se watermark ficou parado em `ctl.etl_control`.
