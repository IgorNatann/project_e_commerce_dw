# Como Executar

## 1) Pre-requisitos

- Python 3.10+
- Dependencias instaladas:

```powershell
pip install -r python/requirements.txt
```

- Scripts SQL de controle ETL ja executados:
  - `sql/dw/03_etl_control/01_create_schema_ctl.sql`
  - `sql/dw/03_etl_control/02_create_etl_control.sql`
  - `sql/dw/03_etl_control/03_create_audit_etl_tables.sql`
  - `sql/dw/03_etl_control/04_seed_etl_control.sql`

## 2) Configurar variaveis de ambiente

Voce pode usar conexao completa ou montar por partes.

### Opcao A: string completa (mais simples)

```powershell
$env:ETL_OLTP_CONN_STR = "Driver={ODBC Driver 18 for SQL Server};Server=localhost,1433;Database=ECOMMERCE_OLTP;Trusted_Connection=yes;TrustServerCertificate=yes;"
$env:ETL_DW_CONN_STR   = "Driver={ODBC Driver 18 for SQL Server};Server=localhost,1433;Database=DW_ECOMMERCE;Trusted_Connection=yes;TrustServerCertificate=yes;"
```

### Opcao B: montar por partes

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 18 for SQL Server"
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
$env:ETL_OLTP_DB = "ECOMMERCE_OLTP"
$env:ETL_DW_DB = "DW_ECOMMERCE"
```

## 3) Executar

### Execucao normal

```powershell
python python/etl/run_etl.py --entity dim_cliente
```

### Dry-run (sem gravar no DW)

```powershell
python python/etl/run_etl.py --entity dim_cliente --dry-run
```

### Com batch customizado

```powershell
python python/etl/run_etl.py --entity dim_cliente --batch-size 500
```

## 4) Conferir resultado

```sql
SELECT TOP 20 * FROM audit.etl_run ORDER BY started_at DESC;
SELECT TOP 20 * FROM audit.etl_run_entity ORDER BY entity_started_at DESC;
SELECT entity_name, watermark_updated_at, watermark_id FROM ctl.etl_control WHERE entity_name = 'dim_cliente';
```

## 5) Monitoramento visual (opcional)

```powershell
streamlit run python/etl/monitoring/app.py
```
