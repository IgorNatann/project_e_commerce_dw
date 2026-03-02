# Fluxo Dos Testes Unitarios De DB

Este diagrama documenta o fluxo da suite `python/tests/test_db.py`, mostrando:

- preparacao do ambiente de teste (dubles e monkeypatch);
- cenarios cobertos por funcao;
- garantias obtidas em cada grupo de testes;
- limite do escopo (nao valida conexao real com SQL Server).

## Fluxo Geral Da Execucao

```mermaid
flowchart TD
    A["Inicio: pytest executa python/tests/test_db.py"] --> B["Bootstrap de import:<br/>adiciona python/etl ao sys.path"]
    B --> C["Cria infraestrutura fake:<br/>DummyConnection + DummyCursor"]
    C --> D["Fixture dummy_conn dispoivel para os testes"]

    D --> E{"Grupo de teste"}

    E --> E1["connect_sqlserver"]
    E --> E2["close_quietly"]
    E --> E3["read_sql_file"]
    E --> E4["query_all"]
    E --> E5["query_one"]
    E --> E6["execute"]

    E1 --> E1A["monkeypatch pyodbc.connect"]
    E1A --> E1B["valida retorno da conexao"]
    E1B --> E1C["valida timeout aplicado"]
    E1 --> E1D["cenario pyodbc ausente -> ModuleNotFoundError"]

    E2 --> E2A["close_quietly(None) nao quebra"]
    E2 --> E2B["close_quietly(conexao) fecha"]
    E2 --> E2C["erro no close nao propaga"]

    E3 --> E3A["SQL_DIR apontado para tmp_path"]
    E3A --> E3B["arquivo SQL de exemplo"]
    E3B --> E3C["read_sql_file le UTF-8 + strip()"]

    E4 --> E4A["executa SQL com params"]
    E4A --> E4B["fetchall + description -> list[dict]"]
    E4B --> E4C["cursor sempre fechado"]
    E4 --> E4D["sem description -> [{}] por linha"]

    E5 --> E5A["sem linha -> retorna None"]
    E5 --> E5B["com linha -> retorna dict"]
    E5A --> E5C["cursor sempre fechado"]
    E5B --> E5C

    E6 --> E6A["executa DML"]
    E6A --> E6B["retorna rowcount"]
    E6B --> E6C["cursor sempre fechado"]

    E1C --> F["Resultado esperado: 9 cenarios PASS"]
    E1D --> F
    E2C --> F
    E3C --> F
    E4D --> F
    E5C --> F
    E6C --> F

    F --> G["Garantia: contrato unitario da camada db.py preservado"]
    G --> H["Fora do escopo: conectividade real SQL Server (Docker/rede/credenciais)"]
```

## Mapa De Garantias Por Funcao

```mermaid
flowchart LR
    subgraph FUNCS["Funcoes em python/etl/db.py"]
        C1["connect_sqlserver"]
        C2["close_quietly"]
        C3["read_sql_file"]
        C4["query_all"]
        C5["query_one"]
        C6["execute"]
    end

    subgraph GAR["Garantias validadas por test_db.py"]
        G1["Conexao usa autocommit=False e timeout configurado"]
        G2["Erro claro quando pyodbc nao existe"]
        G3["Fechamento seguro em sucesso/erro"]
        G4["Leitura de SQL com strip()"]
        G5["Mapeamento de linhas para dict por colunas"]
        G6["Retorno None para ausencia de linha"]
        G7["Retorno de rowcount em DML"]
    end

    C1 --> G1
    C1 --> G2
    C2 --> G3
    C3 --> G4
    C4 --> G5
    C5 --> G6
    C6 --> G7
```

## Comando Para Visualizar O Fluxo Na Pratica

```powershell
python -m pytest -q python/tests/test_db.py
```

