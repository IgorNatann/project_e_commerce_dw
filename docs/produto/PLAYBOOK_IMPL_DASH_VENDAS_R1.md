# Playbook Executavel - Dashboard de Vendas (R1)

Objetivo: publicar e consumir o dashboard de vendas com dados confiaveis do DW, mantendo a monitoria ETL separada.

## 0. Pre-requisitos

- Docker Desktop ativo.
- Stack da infraestrutura levantada.
- ETL da `fact_vendas` implementado no branch atual.

Comando de validacao rapida da stack:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Esperado: `dw_sqlserver` e `dw_etl_monitor` em `Up`.

## 1. Garantir dados de vendas atualizados

Executar carga incremental:

```powershell
docker exec dw_etl_monitor python python/etl/run_etl.py --entity fact_vendas --cutoff-minutes 0
```

Validar status e watermark:

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -Q "SET NOCOUNT ON; SELECT entity_name, is_active, last_status, watermark_updated_at, watermark_id FROM ctl.etl_control WHERE entity_name='fact_vendas'; SELECT TOP 5 run_entity_id, run_id, status, extracted_count, upserted_count, entity_finished_at FROM audit.etl_run_entity WHERE entity_name='fact_vendas' ORDER BY run_entity_id DESC;"
```

Critico para seguir:
- `last_status = success`.
- sem falhas recentes na entidade.

## 2. Validar qualidade minima do dataset

Executar checks de consistencia:

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -Q "SET NOCOUNT ON; SELECT COUNT_BIG(*) AS total_fato, COUNT_BIG(DISTINCT venda_original_id) AS distinct_nk FROM fact.FACT_VENDAS; SELECT COUNT_BIG(*) AS fk_data_missing FROM fact.FACT_VENDAS fv LEFT JOIN dim.DIM_DATA d ON d.data_id=fv.data_id WHERE d.data_id IS NULL; SELECT COUNT_BIG(*) AS fk_cliente_missing FROM fact.FACT_VENDAS fv LEFT JOIN dim.DIM_CLIENTE c ON c.cliente_id=fv.cliente_id WHERE c.cliente_id IS NULL; SELECT COUNT_BIG(*) AS fk_produto_missing FROM fact.FACT_VENDAS fv LEFT JOIN dim.DIM_PRODUTO p ON p.produto_id=fv.produto_id WHERE p.produto_id IS NULL; SELECT COUNT_BIG(*) AS fk_regiao_missing FROM fact.FACT_VENDAS fv LEFT JOIN dim.DIM_REGIAO r ON r.regiao_id=fv.regiao_id WHERE r.regiao_id IS NULL;"
```

Critico para seguir:
- `total_fato = distinct_nk`.
- todas as contagens `fk_*_missing = 0`.

## 3. Criar camada de consumo do dashboard (view certificada)

Criar script SQL da view de consumo:
- caminho sugerido: `sql/dw/04_views/12_vw_dash_vendas_r1.sql`
- nome sugerido: `fact.VW_DASH_VENDAS_R1`

Aplicar script no banco:

```powershell
docker cp sql/dw/04_views/12_vw_dash_vendas_r1.sql dw_sqlserver:/tmp/12_vw_dash_vendas_r1.sql
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -b -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -i /tmp/12_vw_dash_vendas_r1.sql
```

Smoke test da view:

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -Q "SET NOCOUNT ON; SELECT TOP 10 * FROM fact.VW_DASH_VENDAS_R1 ORDER BY data_completa DESC;"
```

## 4. Criar usuario somente leitura para BI

Aplicar script de seguranca (recomendado):
- caminho sugerido: `sql/dw/05_security/01_create_bi_reader.sql`

Exemplo de comandos:

```powershell
docker cp sql/dw/05_security/01_create_bi_reader.sql dw_sqlserver:/tmp/01_create_bi_reader.sql
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -b -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -v BI_READER_PASSWORD="<BI_PASSWORD>" -i /tmp/01_create_bi_reader.sql
```

Validar acesso somente leitura:

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U bi_reader -P "<BI_PASSWORD>" -d DW_ECOMMERCE -Q "SET NOCOUNT ON; SELECT TOP 1 * FROM fact.VW_DASH_VENDAS_R1;"
```

Critico para seguir:
- usuario `bi_reader` consulta dados.
- usuario `bi_reader` nao tem permissao de `INSERT/UPDATE/DELETE`.

## 5. Implementar app Streamlit de vendas (servico separado)

Estrutura recomendada:

```text
python/dashboards/vendas/
|-- app.py
|-- requirements.txt
`-- README.md
```

MVP minimo do app:
- KPIs: receita liquida, ticket medio, itens vendidos, margem bruta.
- Filtros: periodo, estado/regiao, categoria, vendedor.
- Graficos: tendencia mensal, top produtos, top regioes.
- Dicionario de metricas visivel para usuario final (RF-13).

Execucao local rapida:

```powershell
streamlit run python/dashboards/vendas/app.py
```

## 6. Publicar via Docker (novo servico)

Recomendacao: manter monitor ETL em `8501` e dashboard de vendas em `8502`.

Arquivos esperados:
- `docker/streamlit-vendas.Dockerfile`
- novo servico `streamlit-vendas` no `docker/docker-compose.sqlserver.yml`
- variaveis `.env.sqlserver`: `STREAMLIT_VENDAS_BIND_IP`, `STREAMLIT_VENDAS_PORT`

Subir somente o novo servico:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml up -d --build streamlit-vendas
```

Validar health:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml ps
```

Esperado: `streamlit-vendas` com status `healthy`.

## 7. Homologacao funcional (UAT)

Checklist de homologacao:

- [ ] KPI no dashboard bate com query SQL de referencia.
- [ ] Filtros retornam dados coerentes.
- [ ] Performance aceitavel (consultas principais <= 10s).
- [ ] Sem erro de permissao/conexao durante navegacao.

Query referencia (exemplo receita por mes):

```powershell
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -Q "SET NOCOUNT ON; SELECT ano, mes, SUM(valor_total_liquido) AS receita_liquida FROM fact.VW_DASH_VENDAS_R1 GROUP BY ano, mes ORDER BY ano DESC, mes DESC;"
```

Query consolidada de homologacao por KPI:

```powershell
docker cp docs/queries/vendas/01_kpis_dash_vendas_r1.sql dw_sqlserver:/tmp/01_kpis_dash_vendas_r1.sql
docker exec dw_sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "<SA_PASSWORD>" -d DW_ECOMMERCE -i /tmp/01_kpis_dash_vendas_r1.sql
```

## 8. Go-live e consumo

- [ ] Publicar URL final para usuarios.
- [ ] Registrar README operacional do dashboard.
- [ ] Definir horario oficial de consumo (apos janela ETL).
- [ ] Registrar responsavel por suporte de primeiro nivel.

Formato de comunicacao sugerido:

```text
Dashboard de Vendas R1
URL: http://localhost:8502
Atualizacao: diaria apos ETL
Contato: <responsavel>
```

## 9. Rollback rapido

Se deploy quebrar:

```powershell
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml stop streamlit-vendas
docker compose --env-file docker/.env.sqlserver -f docker/docker-compose.sqlserver.yml rm -f streamlit-vendas
```

Se necessario, voltar para imagem/tag anterior no compose e subir novamente.
