# Como executar o ETL

## 1) Modo recomendado (Docker one-shot)

Subir stack completa:

```powershell
powershell -ExecutionPolicy Bypass -File docker/up_stack.ps1
```

Executar ETL da `dim_cliente`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente
```

Executar ETL da `dim_produto`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_produto
```

Executar ETL da `dim_regiao`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_regiao
```

Executar ETL da `dim_vendedor`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_vendedor
```

Executar ETL da `dim_equipe`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_equipe
```

Executar ETL da `dim_desconto`:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_desconto
```

Dry-run:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente --dry-run
```

Com batch customizado:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity dim_cliente --batch-size 500
```

Para executar tudo que estiver ativo no controle:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity all
```

Observacao: para executar uma entidade especifica, ela precisa estar ativa em `ctl.etl_control` (`is_active = 1`).

## 2) Modo local (fora do container)

Pre-requisitos:

- Python 3.10+
- Dependencias instaladas

```powershell
pip install -r dashboards/streamlit/monitoring/requirements.txt
```

Configurar conexao SQL Server (autenticacao SQL):

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 18 for SQL Server"
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
$env:ETL_SQL_USER = "etl_monitor"
$env:ETL_SQL_PASSWORD = "<senha de MSSQL_MONITOR_PASSWORD>"
$env:ETL_OLTP_DB = "ECOMMERCE_OLTP"
$env:ETL_DW_DB = "DW_ECOMMERCE"
```

Executar:

```powershell
python python/etl/run_etl.py --entity dim_cliente
python python/etl/run_etl.py --entity dim_produto
python python/etl/run_etl.py --entity dim_regiao
python python/etl/run_etl.py --entity dim_vendedor
python python/etl/run_etl.py --entity dim_equipe
python python/etl/run_etl.py --entity dim_desconto
```

## 3) Conferir resultado

```sql
SELECT TOP 20 * FROM audit.etl_run ORDER BY started_at DESC;
SELECT TOP 20 * FROM audit.etl_run_entity ORDER BY entity_started_at DESC;
SELECT entity_name, watermark_updated_at, watermark_id
FROM ctl.etl_control
WHERE entity_name IN ('dim_cliente', 'dim_produto', 'dim_regiao', 'dim_vendedor', 'dim_equipe', 'dim_desconto');
```

## 4) Monitoramento visual

Via Docker (recomendado):

- `http://localhost:8501`

Via local:

```powershell
python -m streamlit run dashboards/streamlit/monitoring/app.py
```
