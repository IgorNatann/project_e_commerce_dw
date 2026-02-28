from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

try:
    import pyodbc  # type: ignore
except ModuleNotFoundError:  # pragma: no cover - depende do ambiente local
    pyodbc = None

from config import SQL_DIR


def connect_sqlserver(conn_str: str, *, command_timeout_seconds: int = 120):
    pyodbc_module = _require_pyodbc()
    connection = pyodbc_module.connect(conn_str, autocommit=False)
    connection.timeout = command_timeout_seconds
    return connection


def close_quietly(connection: Any | None) -> None:
    if connection is None:
        return
    try:
        connection.close()
    except Exception:  # noqa: BLE001
        pass


def read_sql_file(relative_path: str | Path) -> str:
    sql_path = SQL_DIR / relative_path
    return sql_path.read_text(encoding="utf-8").strip()


def query_all(
    connection: Any,
    sql: str,
    params: Iterable[Any] = (),
) -> list[dict[str, Any]]:
    cursor = connection.cursor()
    try:
        cursor.execute(sql, tuple(params))
        rows = cursor.fetchall()
        columns = [col[0] for col in cursor.description or []]
        return [dict(zip(columns, row)) for row in rows]
    finally:
        cursor.close()


def query_one(
    connection: Any,
    sql: str,
    params: Iterable[Any] = (),
) -> dict[str, Any] | None:
    cursor = connection.cursor()
    try:
        cursor.execute(sql, tuple(params))
        row = cursor.fetchone()
        if row is None:
            return None
        columns = [col[0] for col in cursor.description or []]
        return dict(zip(columns, row))
    finally:
        cursor.close()


def execute(
    connection: Any,
    sql: str,
    params: Iterable[Any] = (),
) -> int:
    cursor = connection.cursor()
    try:
        cursor.execute(sql, tuple(params))
        return cursor.rowcount
    finally:
        cursor.close()


def _require_pyodbc():
    if pyodbc is None:
        raise ModuleNotFoundError(
            "Dependencia ausente: pyodbc. Instale com `pip install -r python/etl/monitoring/requirements.txt`."
        )
    return pyodbc
