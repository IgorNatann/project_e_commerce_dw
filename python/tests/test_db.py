"""Suite de testes unitarios para `python/etl/db.py`.

Proposito deste arquivo:
- validar a logica da camada de banco sem conectar em SQL Server real;
- garantir fechamento de cursor/conexao em fluxo normal e em erro;
- documentar comportamento esperado de cada funcao utilitaria de `db.py`.

Como ler os testes:
1. Infra de teste: `DummyCursor` e `DummyConnection` simulam pyodbc.
2. Casos de conexao: sucesso e ausencia de dependencia (`pyodbc`).
3. Casos de utilitarios: close seguro, leitura de SQL, query_all/query_one/execute.

Limite intencional:
- estes testes sao unitarios (mock/fake). Conectividade real deve ficar em
  testes de integracao separados.
"""

import sys
from pathlib import Path
import types
import pytest

# Garante que `python/etl` esteja no path para importar `db.py` e `config.py`.
ETL_DIR = Path(__file__).resolve().parents[1] / "etl"
if str(ETL_DIR) not in sys.path:
    sys.path.insert(0, str(ETL_DIR))

import db as dbmod  # noqa: E402
import config as cfg  # noqa: E402


class DummyCursor:
    """Cursor fake com o contrato minimo usado em `db.py`.

    Campos mais importantes para os asserts:
    - `executed`: historico de chamadas `execute(sql, params)`;
    - `_rows`: linhas retornadas por `fetchall`/`fetchone`;
    - `description`: metadados de colunas no formato pyodbc;
    - `rowcount`: quantidade de linhas afetadas (usado em `execute`);
    - `closed`: indica se `close()` foi chamado.
    """

    def __init__(self):
        self.executed = []
        self._rows = []
        self.description = None
        self.closed = False
        self.rowcount = 0

    def execute(self, sql, params=()):
        self.executed.append((sql, tuple(params)))

    def fetchall(self):
        return list(self._rows)

    def fetchone(self):
        return self._rows[0] if self._rows else None

    def close(self):
        self.closed = True


class DummyConnection:
    """Conexao fake que expone `cursor()` e `close()` como pyodbc.

    - Reusa um unico cursor por simplicidade dos testes.
    - Permite simular falha no fechamento com `_raise_on_close = True`.
    """

    def __init__(self):
        self._cursor = DummyCursor()
        self.timeout = None
        self.closed = False

    def cursor(self):
        return self._cursor

    def close(self):
        if hasattr(self, "_raise_on_close") and self._raise_on_close:
            raise RuntimeError("close failed")
        self.closed = True


@pytest.fixture()
def dummy_conn():
    """Retorna uma conexao fake pronta para os cenarios de teste."""

    return DummyConnection()


def test_connect_sqlserver_sets_timeout_and_returns_connection(monkeypatch):
    """Cenario: conexao bem-sucedida.

    Verifica que `connect_sqlserver`:
    - usa `pyodbc.connect` com `autocommit=False`;
    - retorna a conexao criada;
    - aplica o timeout recebido.
    """

    # Arrange: cria um modulo pyodbc fake com a funcao `connect`.
    dummy_pyodbc = types.SimpleNamespace()
    created_conn = DummyConnection()

    def fake_connect(conn_str, autocommit=False):
        assert conn_str == "Driver={X};Server=s;Database=d;"  # valor arbitrario
        assert autocommit is False
        return created_conn

    dummy_pyodbc.connect = fake_connect

    # Injeta pyodbc fake dentro do modulo testado.
    monkeypatch.setattr(dbmod, "pyodbc", dummy_pyodbc, raising=False)

    # Act
    conn = dbmod.connect_sqlserver("Driver={X};Server=s;Database=d;", command_timeout_seconds=7)

    # Assert
    assert conn is created_conn
    assert conn.timeout == 7


def test_connect_sqlserver_raises_when_pyodbc_missing(monkeypatch):
    """Cenario: dependencia ausente.

    Se `pyodbc` nao estiver disponivel, o modulo deve falhar com erro claro.
    """

    monkeypatch.setattr(dbmod, "pyodbc", None, raising=False)
    with pytest.raises(ModuleNotFoundError) as exc:
        dbmod.connect_sqlserver("anything")
    assert "pyodbc" in str(exc.value)


def test_close_quietly_handles_none_and_exceptions(dummy_conn):
    """Cenario: fechamento resiliente.

    `close_quietly` deve:
    - ignorar `None`;
    - fechar conexao valida;
    - nao propagar excecao se `close()` falhar.
    """

    # None -> nao deve quebrar.
    dbmod.close_quietly(None)

    # Fechamento normal.
    dbmod.close_quietly(dummy_conn)
    assert dummy_conn.closed is True

    # Erro em close nao deve propagar.
    broken = DummyConnection()
    broken._raise_on_close = True
    dbmod.close_quietly(broken)  # nao deve levantar excecao


def test_read_sql_file_reads_and_strips(tmp_path, monkeypatch):
    """Cenario: leitura de arquivo SQL.

    O conteudo deve ser lido em UTF-8 e normalizado com `strip()`.
    """

    # Aponta SQL_DIR para diretorio temporario.
    sql_dir = tmp_path / "sql"
    sql_dir.mkdir(parents=True, exist_ok=True)

    monkeypatch.setattr(cfg, "SQL_DIR", sql_dir, raising=False)
    monkeypatch.setattr(dbmod, "SQL_DIR", sql_dir, raising=False)

    # Cria arquivo SQL de exemplo.
    sql_file = sql_dir / "sample.sql"
    sql_file.write_text("\n  SELECT 1  ;  \n", encoding="utf-8")

    # Act
    content = dbmod.read_sql_file("sample.sql")

    # Assert: texto final e retornado com strip().
    assert content == "SELECT 1  ;"


def test_query_all_returns_list_of_dicts_with_columns(dummy_conn):
    """Cenario: query_all com colunas conhecidas.

    Esperado:
    - SQL executado com parametros;
    - linhas convertidas para lista de dicionarios;
    - cursor fechado no final.
    """

    cur = dummy_conn.cursor()
    cur.description = [("id",), ("name",)]
    cur._rows = [
        (1, "Alice"),
        (2, "Bob"),
    ]

    # Act
    rows = dbmod.query_all(dummy_conn, "SELECT * FROM t WHERE x=?", params=[10])

    # Assert
    assert cur.executed == [("SELECT * FROM t WHERE x=?", (10,))]
    assert rows == [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
    ]
    assert cur.closed is True


def test_query_all_with_no_description_returns_empty_dicts(dummy_conn):
    """Cenario: cursor sem `description`.

    Quando nao ha metadados de coluna, cada linha vira `{}` por causa do zip
    sem chaves. O teste documenta esse comportamento atual.
    """

    cur = dummy_conn.cursor()
    cur.description = None  # sem colunas disponiveis
    cur._rows = [(1, 2, 3)]

    rows = dbmod.query_all(dummy_conn, "SELECT 1")

    assert rows == [{}]  # zip([], row) -> {}
    assert cur.closed is True


def test_query_one_returns_none_when_no_row(dummy_conn):
    """Cenario: query_one sem resultado.

    Deve retornar `None` e fechar o cursor.
    """

    cur = dummy_conn.cursor()
    cur.description = [("id",)]
    cur._rows = []  # sem linhas

    row = dbmod.query_one(dummy_conn, "SELECT * FROM t WHERE id=?", params=[5])

    assert row is None
    assert cur.closed is True


def test_query_one_returns_dict_when_row_exists(dummy_conn):
    """Cenario: query_one com uma linha.

    Deve mapear colunas para valores e retornar um dicionario.
    """

    cur = dummy_conn.cursor()
    cur.description = [("id",), ("v",)]
    cur._rows = [(10, "x")]

    row = dbmod.query_one(dummy_conn, "SELECT * FROM t")

    assert row == {"id": 10, "v": "x"}
    assert cur.closed is True


def test_execute_returns_rowcount_and_closes_cursor(dummy_conn):
    """Cenario: comando DML em `execute`.

    Deve retornar `rowcount` informado pelo cursor e fechar o recurso.
    """

    cur = dummy_conn.cursor()
    cur.rowcount = 3

    affected = dbmod.execute(dummy_conn, "UPDATE t SET x=1")

    assert affected == 3
    assert cur.closed is True
