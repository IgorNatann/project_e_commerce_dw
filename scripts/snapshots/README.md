# Export de Snapshots para Portfolio

Script utilitario para gerar snapshots locais dos dashboards de negocio:

- `fact.VW_DASH_VENDAS_R1` -> `data/snapshots/vendas_r1.*`
- `fact.VW_DASH_METAS_R1` -> `data/snapshots/metas_r1.*`
- `fact.VW_DASH_DESCONTOS_R1` -> `data/snapshots/descontos_r1.*`

## Execucao rapida

```powershell
python scripts/snapshots/export_dash_snapshots.py
```

Com stack Docker local (recomendado):

```powershell
$repo = (Get-Location).Path
docker run --rm --network dw_stack_default -e SNAP_SQL_SERVER=sqlserver -v "${repo}:/workspace" -w /workspace dw_stack-streamlit-vendas python scripts/snapshots/export_dash_snapshots.py --output-dir data/snapshots --dotenv-path docker/.env.sqlserver
```

Default:

- formato: `csv.gz`
- output: `data/snapshots`
- dotenv fallback: `docker/.env.sqlserver`

## Opcoes uteis

Ultimos 365 dias:

```powershell
python scripts/snapshots/export_dash_snapshots.py --days-back 365
```

Parquet:

```powershell
python scripts/snapshots/export_dash_snapshots.py --format parquet
```

## Variaveis de conexao

Prioridade principal:

- `SNAP_SQL_DRIVER`
- `SNAP_SQL_SERVER`
- `SNAP_SQL_PORT`
- `SNAP_DW_DB`
- `SNAP_SQL_USER`
- `SNAP_SQL_PASSWORD`
- `SNAP_SQL_ENCRYPT`
- `SNAP_SQL_TRUST_SERVER_CERTIFICATE`
- `SNAP_SQL_TIMEOUT_SECONDS`

Fallback aceito:

- `DASH_SQL_*`
- `MSSQL_BI_PASSWORD`

## Saidas

Arquivos gerados em `data/snapshots`:

- snapshots (`*.csv`, `*.csv.gz` ou `*.parquet`)
- `manifest.json` com timestamp, row_count e faixa de datas
