# Troubleshooting

## 1) `pyodbc.InterfaceError: Data source name not found`

Causa comum: driver ODBC nao instalado ou nome diferente.

Checklist:

1. Verifique se o driver existe no Windows (`ODBC Driver 18 for SQL Server`).
2. Se o nome for outro, ajuste:

```powershell
$env:ETL_SQL_DRIVER = "ODBC Driver 17 for SQL Server"
```

## 2) Falha de conexao com SQL Server

Checklist:

1. Confirme servidor/porta:

```powershell
$env:ETL_SQL_SERVER = "localhost"
$env:ETL_SQL_PORT = "1433"
```

2. Se usar autenticacao SQL:

```powershell
$env:ETL_SQL_USER = "sa"
$env:ETL_SQL_PASSWORD = "SuaSenha"
```

3. Se usar certificado local/self-signed:

```powershell
$env:ETL_SQL_TRUST_SERVER_CERTIFICATE = "yes"
```

## 3) `Entidade 'dim_cliente' nao encontrada em ctl.etl_control`

Causa: faltou executar seed de controle.

Solucao:

1. Execute os scripts da pasta `sql/dw/03_etl_control` na ordem.
2. Valide:

```sql
SELECT *
FROM ctl.etl_control
WHERE entity_name = 'dim_cliente';
```

## 4) Erro em constraint da `dim.DIM_CLIENTE` (tipo/segmento/estado)

Causa: valor invalido para colunas com CHECK.

Onde ajustar:

- `python/etl/entities/dim_cliente.py`
  - `_normalize_tipo_cliente`
  - `_normalize_segmento`
  - `_normalize_state`

## 5) Dry-run nao atualiza watermark

Comportamento esperado.

- `--dry-run` executa extracao/transformacao
- nao faz upsert
- nao avanca watermark em `ctl.etl_control`

Use sem `--dry-run` para gravar de fato.

## 6) Rodou, mas sem novos registros

Possiveis causas:

1. Sem alteracoes no OLTP apos o watermark atual.
2. `cutoff_minutes` alto demais.
3. Watermark avancou em execucao anterior.

Conferir:

```sql
SELECT entity_name, watermark_updated_at, watermark_id, cutoff_minutes
FROM ctl.etl_control
WHERE entity_name = 'dim_cliente';
```

Se precisar reprocessar janela antiga para teste, ajuste watermark manualmente com cuidado.
