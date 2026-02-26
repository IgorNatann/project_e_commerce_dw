from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
SQL_DIR = BASE_DIR / "sql"


@dataclass(frozen=True)
class ETLConfig:
    oltp_conn_str: str
    dw_conn_str: str
    default_batch_size: int = 1000
    default_cutoff_minutes: int = 2
    command_timeout_seconds: int = 120

    @classmethod
    def from_env(cls) -> "ETLConfig":
        oltp_conn_str = os.getenv("ETL_OLTP_CONN_STR") or _build_conn_str(
            database_env="ETL_OLTP_DB",
            fallback_database="ECOMMERCE_OLTP",
        )
        dw_conn_str = os.getenv("ETL_DW_CONN_STR") or _build_conn_str(
            database_env="ETL_DW_DB",
            fallback_database="DW_ECOMMERCE",
        )

        return cls(
            oltp_conn_str=oltp_conn_str,
            dw_conn_str=dw_conn_str,
            default_batch_size=_safe_int(os.getenv("ETL_DEFAULT_BATCH_SIZE"), 1000),
            default_cutoff_minutes=_safe_int(os.getenv("ETL_DEFAULT_CUTOFF_MINUTES"), 2),
            command_timeout_seconds=_safe_int(os.getenv("ETL_SQL_TIMEOUT_SECONDS"), 120),
        )


def _build_conn_str(database_env: str, fallback_database: str) -> str:
    driver = os.getenv("ETL_SQL_DRIVER", "ODBC Driver 18 for SQL Server")
    server = os.getenv("ETL_SQL_SERVER", "localhost")
    port = os.getenv("ETL_SQL_PORT", "1433")
    database = os.getenv(database_env, fallback_database)
    trust_server_certificate = os.getenv("ETL_SQL_TRUST_SERVER_CERTIFICATE", "yes")
    encrypt = os.getenv("ETL_SQL_ENCRYPT", "yes")

    user = os.getenv("ETL_SQL_USER")
    password = os.getenv("ETL_SQL_PASSWORD")

    if user and password:
        return (
            f"Driver={{{driver}}};"
            f"Server={server},{port};"
            f"Database={database};"
            f"UID={user};"
            f"PWD={password};"
            f"Encrypt={encrypt};"
            f"TrustServerCertificate={trust_server_certificate};"
        )

    return (
        f"Driver={{{driver}}};"
        f"Server={server},{port};"
        f"Database={database};"
        "Trusted_Connection=yes;"
        f"Encrypt={encrypt};"
        f"TrustServerCertificate={trust_server_certificate};"
    )


def _safe_int(raw_value: str | None, default: int) -> int:
    if raw_value is None:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default
