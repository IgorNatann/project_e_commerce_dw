#!/usr/bin/env python3
"""Checks minimos de integridade do DW para execucao recorrente."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from typing import Any

try:
    import pyodbc  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    pyodbc = None


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _resolve_sql_driver() -> str:
    explicit_driver = os.getenv("ETL_SQL_DRIVER")
    if explicit_driver:
        return explicit_driver

    installed: list[str] = []
    if pyodbc is not None:
        try:
            installed = list(pyodbc.drivers())
        except Exception:  # noqa: BLE001
            installed = []

    for driver in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"):
        if driver in installed:
            return driver
    return "ODBC Driver 18 for SQL Server"


def _build_conn_str() -> str:
    driver = _resolve_sql_driver()
    server = os.getenv("ETL_SQL_SERVER", "sqlserver")
    port = os.getenv("ETL_SQL_PORT", "").strip()
    database = os.getenv("ETL_DW_DB", "DW_ECOMMERCE")
    user = os.getenv("ETL_SQL_USER", "etl_monitor")
    password = os.getenv("ETL_SQL_PASSWORD", "")
    encrypt = os.getenv("ETL_SQL_ENCRYPT", "yes")
    trust_server_certificate = os.getenv("ETL_SQL_TRUST_SERVER_CERTIFICATE", "yes")

    if not password:
        raise ValueError("Variavel ETL_SQL_PASSWORD nao definida.")

    server_part = f"{server},{port}" if port else server
    return (
        f"Driver={{{driver}}};"
        f"Server={server_part};"
        f"Database={database};"
        f"UID={user};"
        f"PWD={password};"
        f"Encrypt={encrypt};"
        f"TrustServerCertificate={trust_server_certificate};"
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Executa checks minimos de integridade do DW e emite status estruturado."
    )
    parser.add_argument("--json", action="store_true", help="Emite payload JSON.")
    return parser.parse_args()


def _open_connection():
    if pyodbc is None:
        raise ModuleNotFoundError("Dependencia ausente: pyodbc.")
    connection = pyodbc.connect(_build_conn_str(), autocommit=True)
    connection.timeout = _safe_int(os.getenv("ETL_SQL_TIMEOUT_SECONDS"), 120)
    return connection


def _query_scalar(connection, sql: str) -> int:
    cursor = connection.cursor()
    try:
        row = cursor.execute(sql).fetchone()
        if row is None:
            return 0
        return _safe_int(row[0], 0)
    finally:
        cursor.close()


def _run_max_zero_check(connection, check_name: str, sql: str, category: str) -> dict[str, Any]:
    value = _query_scalar(connection, sql)
    return {
        "check": check_name,
        "category": category,
        "ok": value == 0,
        "value": value,
        "expected": "0",
    }


def _run_minimum_check(
    connection,
    check_name: str,
    sql: str,
    category: str,
    minimum: int = 1,
) -> dict[str, Any]:
    value = _query_scalar(connection, sql)
    return {
        "check": check_name,
        "category": category,
        "ok": value >= minimum,
        "value": value,
        "expected": f">={minimum}",
    }


def run_checks(connection) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []

    fk_orphan_checks = [
        (
            "fk_orfa_fact_vendas_data",
            """
            SELECT COUNT(*)
            FROM fact.FACT_VENDAS fv
            LEFT JOIN dim.DIM_DATA d ON d.data_id = fv.data_id
            WHERE d.data_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_vendas_cliente",
            """
            SELECT COUNT(*)
            FROM fact.FACT_VENDAS fv
            LEFT JOIN dim.DIM_CLIENTE c ON c.cliente_id = fv.cliente_id
            WHERE c.cliente_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_vendas_produto",
            """
            SELECT COUNT(*)
            FROM fact.FACT_VENDAS fv
            LEFT JOIN dim.DIM_PRODUTO p ON p.produto_id = fv.produto_id
            WHERE p.produto_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_vendas_regiao",
            """
            SELECT COUNT(*)
            FROM fact.FACT_VENDAS fv
            LEFT JOIN dim.DIM_REGIAO r ON r.regiao_id = fv.regiao_id
            WHERE r.regiao_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_metas_vendedor",
            """
            SELECT COUNT(*)
            FROM fact.FACT_METAS fm
            LEFT JOIN dim.DIM_VENDEDOR v ON v.vendedor_id = fm.vendedor_id
            WHERE v.vendedor_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_metas_data",
            """
            SELECT COUNT(*)
            FROM fact.FACT_METAS fm
            LEFT JOIN dim.DIM_DATA d ON d.data_id = fm.data_id
            WHERE d.data_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_descontos_desconto",
            """
            SELECT COUNT(*)
            FROM fact.FACT_DESCONTOS fd
            LEFT JOIN dim.DIM_DESCONTO dd ON dd.desconto_id = fd.desconto_id
            WHERE dd.desconto_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_descontos_venda",
            """
            SELECT COUNT(*)
            FROM fact.FACT_DESCONTOS fd
            LEFT JOIN fact.FACT_VENDAS fv ON fv.venda_id = fd.venda_id
            WHERE fv.venda_id IS NULL;
            """,
        ),
        (
            "fk_orfa_fact_descontos_data",
            """
            SELECT COUNT(*)
            FROM fact.FACT_DESCONTOS fd
            LEFT JOIN dim.DIM_DATA d ON d.data_id = fd.data_aplicacao_id
            WHERE d.data_id IS NULL;
            """,
        ),
    ]

    duplicate_key_checks = [
        (
            "duplicidade_nk_dim_cliente",
            """
            SELECT COUNT(*) FROM (
                SELECT cliente_original_id
                FROM dim.DIM_CLIENTE
                GROUP BY cliente_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_dim_produto",
            """
            SELECT COUNT(*) FROM (
                SELECT produto_original_id
                FROM dim.DIM_PRODUTO
                GROUP BY produto_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_dim_regiao",
            """
            SELECT CASE
                WHEN COL_LENGTH('dim.DIM_REGIAO', 'regiao_original_id') IS NULL THEN 0
                ELSE (
                    SELECT COUNT(*) FROM (
                        SELECT regiao_original_id
                        FROM dim.DIM_REGIAO
                        GROUP BY regiao_original_id
                        HAVING COUNT(*) > 1
                    ) d
                )
            END;
            """,
        ),
        (
            "duplicidade_nk_dim_equipe",
            """
            SELECT COUNT(*) FROM (
                SELECT equipe_original_id
                FROM dim.DIM_EQUIPE
                GROUP BY equipe_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_dim_vendedor",
            """
            SELECT COUNT(*) FROM (
                SELECT vendedor_original_id
                FROM dim.DIM_VENDEDOR
                GROUP BY vendedor_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_dim_desconto",
            """
            SELECT COUNT(*) FROM (
                SELECT desconto_original_id
                FROM dim.DIM_DESCONTO
                GROUP BY desconto_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_fact_vendas",
            """
            SELECT COUNT(*) FROM (
                SELECT venda_original_id
                FROM fact.FACT_VENDAS
                GROUP BY venda_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_fact_metas",
            """
            SELECT COUNT(*) FROM (
                SELECT vendedor_id, data_id, tipo_periodo
                FROM fact.FACT_METAS
                GROUP BY vendedor_id, data_id, tipo_periodo
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
        (
            "duplicidade_nk_fact_descontos",
            """
            SELECT COUNT(*) FROM (
                SELECT desconto_aplicado_original_id
                FROM fact.FACT_DESCONTOS
                GROUP BY desconto_aplicado_original_id
                HAVING COUNT(*) > 1
            ) d;
            """,
        ),
    ]

    coverage_checks = [
        ("cobertura_dim_cliente", "SELECT COUNT(*) FROM dim.DIM_CLIENTE;", 1),
        ("cobertura_dim_produto", "SELECT COUNT(*) FROM dim.DIM_PRODUTO;", 1),
        ("cobertura_dim_regiao", "SELECT COUNT(*) FROM dim.DIM_REGIAO;", 1),
        ("cobertura_dim_equipe", "SELECT COUNT(*) FROM dim.DIM_EQUIPE;", 1),
        ("cobertura_dim_vendedor", "SELECT COUNT(*) FROM dim.DIM_VENDEDOR;", 1),
        ("cobertura_dim_desconto", "SELECT COUNT(*) FROM dim.DIM_DESCONTO;", 1),
        ("cobertura_fact_vendas", "SELECT COUNT(*) FROM fact.FACT_VENDAS;", 1),
        ("cobertura_fact_metas", "SELECT COUNT(*) FROM fact.FACT_METAS;", 1),
        ("cobertura_fact_descontos", "SELECT COUNT(*) FROM fact.FACT_DESCONTOS;", 1),
        ("cobertura_vw_dash_vendas_r1", "SELECT COUNT(*) FROM fact.VW_DASH_VENDAS_R1;", 1),
        ("cobertura_vw_dash_metas_r1", "SELECT COUNT(*) FROM fact.VW_DASH_METAS_R1;", 1),
        ("cobertura_vw_dash_descontos_r1", "SELECT COUNT(*) FROM fact.VW_DASH_DESCONTOS_R1;", 1),
    ]

    for check_name, sql in fk_orphan_checks:
        checks.append(_run_max_zero_check(connection, check_name, sql, "integridade_fk"))
    for check_name, sql in duplicate_key_checks:
        checks.append(_run_max_zero_check(connection, check_name, sql, "unicidade_nk"))
    for check_name, sql, minimum in coverage_checks:
        checks.append(_run_minimum_check(connection, check_name, sql, "cobertura_minima", minimum))

    return checks


def _build_payload(checks: list[dict[str, Any]]) -> dict[str, Any]:
    total_checks = len(checks)
    failed = sum(1 for check in checks if check.get("ok") is False)
    passed = total_checks - failed
    return {
        "suite": "dw_integrity_minimum",
        "generated_at_utc": datetime.now(tz=timezone.utc).isoformat(),
        "summary": {
            "total_checks": total_checks,
            "passed": passed,
            "failed": failed,
        },
        "checks": checks,
    }


def main() -> int:
    args = _parse_args()
    connection = _open_connection()
    try:
        payload = _build_payload(run_checks(connection))
    finally:
        connection.close()

    summary = payload["summary"]
    if args.json:
        print(json.dumps(payload, ensure_ascii=True))
    else:
        print(
            "[dw-integrity] checks: "
            f"{summary['passed']}/{summary['total_checks']} aprovados "
            f"(falhas={summary['failed']})"
        )
        for item in payload["checks"]:
            status = "OK" if item["ok"] else "FAIL"
            print(f"- {status} {item['check']} value={item['value']} expected={item['expected']}")

    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
