#!/usr/bin/env python3
"""Exporta snapshots dos dashboards (vendas, metas e descontos) a partir do DW."""

from __future__ import annotations

import argparse
import json
import os
import warnings
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd

try:
    import pyodbc  # type: ignore
except ImportError:  # pragma: no cover
    pyodbc = None


@dataclass(frozen=True)
class SnapshotDefinition:
    key: str
    view_name: str
    date_column: str


SNAPSHOT_DEFINITIONS = [
    SnapshotDefinition("vendas_r1", "fact.VW_DASH_VENDAS_R1", "data_completa"),
    SnapshotDefinition("metas_r1", "fact.VW_DASH_METAS_R1", "data_completa"),
    SnapshotDefinition("descontos_r1", "fact.VW_DASH_DESCONTOS_R1", "data_completa"),
]

warnings.filterwarnings(
    "ignore",
    category=UserWarning,
    message="pandas only supports SQLAlchemy connectable.*",
)


def _load_dotenv_file(dotenv_path: Path) -> None:
    if not dotenv_path.exists():
        return

    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key and key not in os.environ:
            os.environ[key] = value


def _get_env(name: str, aliases: tuple[str, ...] = (), default: str = "") -> str:
    value = os.getenv(name, "").strip()
    if value:
        return value
    for alias in aliases:
        alias_value = os.getenv(alias, "").strip()
        if alias_value:
            return alias_value
    return default


def _resolve_sql_driver() -> str:
    explicit_driver = _get_env("SNAP_SQL_DRIVER", aliases=("DASH_SQL_DRIVER",))
    if explicit_driver:
        return explicit_driver

    installed: list[str] = []
    if pyodbc is not None:
        try:
            installed = list(pyodbc.drivers())
        except Exception:  # noqa: BLE001
            installed = []

    preferred = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server",
    ]
    for driver in preferred:
        if driver in installed:
            return driver
    return "ODBC Driver 18 for SQL Server"


def _build_conn_str() -> str:
    if pyodbc is None:
        raise ModuleNotFoundError(
            "Dependencia ausente: pyodbc. Instale com `pip install pyodbc pandas`."
        )

    driver = _resolve_sql_driver()
    server = _get_env("SNAP_SQL_SERVER", aliases=("DASH_SQL_SERVER",), default="localhost")
    port = _get_env("SNAP_SQL_PORT", aliases=("DASH_SQL_PORT",), default="1433")
    database = _get_env("SNAP_DW_DB", aliases=("DASH_DW_DB",), default="DW_ECOMMERCE")
    user = _get_env("SNAP_SQL_USER", aliases=("DASH_SQL_USER",), default="bi_reader")
    password = _get_env(
        "SNAP_SQL_PASSWORD",
        aliases=("DASH_SQL_PASSWORD", "MSSQL_BI_PASSWORD"),
    )
    encrypt = _get_env("SNAP_SQL_ENCRYPT", aliases=("DASH_SQL_ENCRYPT",), default="yes")
    trust = _get_env(
        "SNAP_SQL_TRUST_SERVER_CERTIFICATE",
        aliases=("DASH_SQL_TRUST_SERVER_CERTIFICATE",),
        default="yes",
    )

    if not password:
        raise ValueError(
            "Senha SQL nao configurada. Defina SNAP_SQL_PASSWORD, DASH_SQL_PASSWORD ou MSSQL_BI_PASSWORD."
        )

    server_part = f"{server},{port}" if port else server
    return (
        f"Driver={{{driver}}};"
        f"Server={server_part};"
        f"Database={database};"
        f"UID={user};"
        f"PWD={password};"
        f"Encrypt={encrypt};"
        f"TrustServerCertificate={trust};"
    )


def _open_connection(conn_str: str):
    if pyodbc is None:
        raise ModuleNotFoundError("Dependencia ausente: pyodbc.")
    conn = pyodbc.connect(conn_str, autocommit=True)
    timeout = int(_get_env("SNAP_SQL_TIMEOUT_SECONDS", aliases=("DASH_SQL_TIMEOUT_SECONDS",), default="120"))
    conn.timeout = max(30, timeout)
    return conn


def _build_query(definition: SnapshotDefinition, days_back: int | None) -> tuple[str, list[Any]]:
    if days_back is None:
        return f"SELECT * FROM {definition.view_name};", []

    query = f"""
    SELECT *
    FROM {definition.view_name}
    WHERE CAST({definition.date_column} AS date) >= DATEADD(DAY, -?, CAST(SYSUTCDATETIME() AS date));
    """
    return query, [int(days_back)]


def _save_snapshot(df: pd.DataFrame, output_path: Path, file_format: str) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if file_format == "csv":
        df.to_csv(output_path, index=False)
        return
    if file_format == "csv.gz":
        df.to_csv(output_path, index=False, compression="gzip")
        return
    if file_format == "parquet":
        df.to_parquet(output_path, index=False)
        return

    raise ValueError(f"Formato nao suportado: {file_format}")


def _build_filename(snapshot_key: str, file_format: str) -> str:
    if file_format == "csv":
        return f"{snapshot_key}.csv"
    if file_format == "csv.gz":
        return f"{snapshot_key}.csv.gz"
    if file_format == "parquet":
        return f"{snapshot_key}.parquet"
    raise ValueError(f"Formato nao suportado: {file_format}")


def _build_manifest_entry(
    definition: SnapshotDefinition,
    output_path: Path,
    row_count: int,
    generated_at_utc: str,
    date_min: str | None,
    date_max: str | None,
) -> dict[str, Any]:
    return {
        "snapshot_key": definition.key,
        "view_name": definition.view_name,
        "file": output_path.name,
        "row_count": row_count,
        "date_min": date_min,
        "date_max": date_max,
        "generated_at_utc": generated_at_utc,
    }


def run_export(output_dir: Path, file_format: str, days_back: int | None) -> int:
    conn_str = _build_conn_str()
    generated_at_utc = datetime.now(timezone.utc).isoformat()
    manifest: dict[str, Any] = {
        "version": 1,
        "generated_at_utc": generated_at_utc,
        "format": file_format,
        "items": {},
    }

    connection = _open_connection(conn_str)
    try:
        for definition in SNAPSHOT_DEFINITIONS:
            query, params = _build_query(definition, days_back)
            print(f"[snapshot-export] lendo {definition.view_name} ...")
            df = pd.read_sql(query, connection, params=params)

            date_min: str | None = None
            date_max: str | None = None
            if definition.date_column in df.columns and not df.empty:
                dt_series = pd.to_datetime(df[definition.date_column], errors="coerce").dropna()
                if not dt_series.empty:
                    date_min = dt_series.min().strftime("%Y-%m-%d")
                    date_max = dt_series.max().strftime("%Y-%m-%d")

            filename = _build_filename(definition.key, file_format)
            output_path = output_dir / filename
            _save_snapshot(df, output_path, file_format)

            manifest["items"][definition.key] = _build_manifest_entry(
                definition=definition,
                output_path=output_path,
                row_count=int(df.shape[0]),
                generated_at_utc=generated_at_utc,
                date_min=date_min,
                date_max=date_max,
            )
            print(f"[snapshot-export] salvo {output_path} ({df.shape[0]} linhas)")
    finally:
        connection.close()

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"[snapshot-export] manifesto salvo em {manifest_path}")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Exporta snapshots dos dashboards para uso offline/portfolio.")
    parser.add_argument(
        "--output-dir",
        default="data/snapshots",
        help="Diretorio de saida dos snapshots (default: data/snapshots).",
    )
    parser.add_argument(
        "--format",
        dest="file_format",
        choices=("csv", "csv.gz", "parquet"),
        default="csv.gz",
        help="Formato dos snapshots (default: csv.gz).",
    )
    parser.add_argument(
        "--days-back",
        type=int,
        default=None,
        help="Opcional: exporta somente os ultimos N dias de cada view.",
    )
    parser.add_argument(
        "--dotenv-path",
        default="docker/.env.sqlserver",
        help="Arquivo .env para preencher variaveis ausentes (default: docker/.env.sqlserver).",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    dotenv_path = Path(args.dotenv_path).resolve()
    _load_dotenv_file(dotenv_path)

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[snapshot-export] output_dir={output_dir}")
    print(f"[snapshot-export] format={args.file_format}")
    if args.days_back is not None:
        print(f"[snapshot-export] days_back={args.days_back}")
    print(f"[snapshot-export] dotenv={dotenv_path}")

    return run_export(output_dir=output_dir, file_format=args.file_format, days_back=args.days_back)


if __name__ == "__main__":
    raise SystemExit(main())
