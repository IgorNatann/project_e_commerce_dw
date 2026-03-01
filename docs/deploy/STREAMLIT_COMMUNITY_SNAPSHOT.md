# Deploy no Streamlit Community (modo snapshot)

Guia rapido para publicar os dashboards de negocio sem SQL Server exposto.

## 1) Gerar snapshots

Com a stack local ativa, execute:

```powershell
python scripts/snapshots/export_dash_snapshots.py
```

Se a conexao local nao funcionar, rode via container:

```powershell
$repo = (Get-Location).Path
docker run --rm --network dw_stack_default -e SNAP_SQL_SERVER=sqlserver -v "${repo}:/workspace" -w /workspace dw_stack-streamlit-vendas python scripts/snapshots/export_dash_snapshots.py --output-dir data/snapshots --dotenv-path docker/.env.sqlserver
```

Arquivos esperados em `data/snapshots/`:

- `vendas_r1.csv.gz`
- `metas_r1.csv.gz`
- `descontos_r1.csv.gz`
- `manifest.json`

## 2) Versionar no GitHub

```powershell
git add data/snapshots scripts/snapshots dashboards/streamlit
git commit -m "feat(snapshot): habilitar dashboards em modo offline para deploy no Streamlit Community"
git push
```

## 3) Criar apps no Streamlit Community

Para cada dashboard, criar um app apontando para:

- `dashboards/streamlit/vendas/app.py`
- `dashboards/streamlit/metas/app.py`
- `dashboards/streamlit/descontos/app.py`

## 4) Environment variables por app

Vendas:

- `USE_SNAPSHOT=true`
- `DASH_USE_SNAPSHOT=true`
- `DASH_SNAPSHOT_PATH=data/snapshots/vendas_r1.csv.gz`

Metas:

- `USE_SNAPSHOT=true`
- `DASH_METAS_USE_SNAPSHOT=true`
- `DASH_METAS_SNAPSHOT_PATH=data/snapshots/metas_r1.csv.gz`

Descontos:

- `USE_SNAPSHOT=true`
- `DASH_DESC_USE_SNAPSHOT=true`
- `DASH_DESC_SNAPSHOT_PATH=data/snapshots/descontos_r1.csv.gz`

## 5) Atualizacao de dados

Sempre que quiser renovar os dados publicados:

1. Rode novamente o export local.
2. Commit/push dos arquivos em `data/snapshots`.
3. Streamlit Community redeploya automaticamente.
