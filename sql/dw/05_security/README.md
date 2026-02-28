# DW - Seguranca de consumo

Scripts de acessos para consumidores analiticos (dashboards e BI), mantendo escrita restrita ao ETL.

## Scripts

- `01_create_bi_reader.sql`: cria/atualiza login `bi_reader` e concede somente `SELECT` nos schemas `dim` e `fact`.

## Execucao

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -b -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -v BI_READER_PASSWORD="<BI_PASSWORD>" -i /workspace/sql/dw/05_security/01_create_bi_reader.sql
```

## Observacao

Esse perfil e recomendado para os dashboards de negocio, separado do usuario tecnico de monitoria ETL (`etl_monitor`).
