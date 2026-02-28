from __future__ import annotations

import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import altair as alt
import pandas as pd
import streamlit as st


ETL_DIR = Path(__file__).resolve().parents[1]
if str(ETL_DIR) not in sys.path:
    sys.path.append(str(ETL_DIR))

from config import ETLConfig  # noqa: E402
from db import close_quietly, connect_sqlserver, execute, query_all, query_one  # noqa: E402


st.set_page_config(
    page_title="ETL Monitor - DW E-commerce",
    page_icon=":bar_chart:",
    layout="wide",
)


def _to_dataframe(rows: list[dict[str, Any]]) -> pd.DataFrame:
    if not rows:
        return pd.DataFrame()
    return pd.DataFrame(rows)


def _extract_conn_attr(conn_str: str, key: str) -> str | None:
    pattern = rf"(?i){re.escape(key)}=([^;]+)"
    match = re.search(pattern, conn_str)
    if not match:
        return None
    return match.group(1).strip()


def _mask_conn_str(conn_str: str) -> str:
    masked = re.sub(r"(?i)(PWD=)([^;]*)", r"\1***", conn_str)
    masked = re.sub(r"(?i)(Password=)([^;]*)", r"\1***", masked)
    return masked


def _to_bool(value: Any) -> bool:
    return bool(int(value)) if value is not None else False


def _to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _parse_table_name(table_name: str) -> tuple[str, str] | None:
    if not table_name:
        return None
    parts = [part.strip().strip("[]") for part in str(table_name).split(".")]
    if len(parts) != 2:
        return None
    if not parts[0] or not parts[1]:
        return None
    return parts[0], parts[1]


def _is_safe_identifier(value: str) -> bool:
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", value))


def _safe_qualified_name(table_name: str) -> str:
    parsed = _parse_table_name(table_name)
    if parsed is None:
        raise ValueError(f"Nome de tabela invalido: {table_name}")
    schema_name, object_name = parsed
    if not _is_safe_identifier(schema_name) or not _is_safe_identifier(object_name):
        raise ValueError(f"Nome de tabela nao seguro: {table_name}")
    return f"[{schema_name}].[{object_name}]"


def _normalize_table_key(table_name: str) -> str | None:
    parsed = _parse_table_name(table_name)
    if parsed is None:
        return None
    schema_name, object_name = parsed
    return f"{schema_name.lower()}.{object_name.lower()}"


def _collect_safe_table_pairs(table_names: list[str]) -> list[tuple[str, str]]:
    seen: set[str] = set()
    pairs: list[tuple[str, str]] = []
    for table_name in table_names:
        parsed = _parse_table_name(str(table_name))
        if parsed is None:
            continue
        schema_name, object_name = parsed
        if not _is_safe_identifier(schema_name) or not _is_safe_identifier(object_name):
            continue
        table_key = f"{schema_name.lower()}.{object_name.lower()}"
        if table_key in seen:
            continue
        seen.add(table_key)
        pairs.append((schema_name, object_name))
    return pairs


def _build_table_filter_sql(
    table_pairs: list[tuple[str, str]],
    schema_column: str,
    table_column: str,
) -> tuple[str, tuple[Any, ...]]:
    if not table_pairs:
        return "1 = 0", ()
    clauses: list[str] = []
    params: list[Any] = []
    for schema_name, table_name in table_pairs:
        clauses.append(f"({schema_column} = ? AND {table_column} = ?)")
        params.extend([schema_name, table_name])
    return " OR ".join(clauses), tuple(params)


def _get_existing_tables(connection: Any, table_names: list[str]) -> set[str]:
    table_pairs = _collect_safe_table_pairs(table_names)
    if not table_pairs:
        return set()
    filter_sql, params = _build_table_filter_sql(table_pairs, "TABLE_SCHEMA", "TABLE_NAME")
    rows = query_all(
        connection,
        f"""
        SELECT
            TABLE_SCHEMA,
            TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
          AND ({filter_sql});
        """,
        params,
    )
    existing: set[str] = set()
    for row in rows:
        schema_name = str(row.get("TABLE_SCHEMA") or "")
        table_name = str(row.get("TABLE_NAME") or "")
        if schema_name and table_name:
            existing.add(f"{schema_name.lower()}.{table_name.lower()}")
    return existing


def _get_table_columns_map(connection: Any, table_names: list[str]) -> dict[str, list[str]]:
    table_pairs = _collect_safe_table_pairs(table_names)
    if not table_pairs:
        return {}
    filter_sql, params = _build_table_filter_sql(table_pairs, "TABLE_SCHEMA", "TABLE_NAME")
    rows = query_all(
        connection,
        f"""
        SELECT
            TABLE_SCHEMA,
            TABLE_NAME,
            COLUMN_NAME,
            ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE ({filter_sql})
        ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
        """,
        params,
    )
    columns_map: dict[str, list[str]] = {}
    for row in rows:
        schema_name = str(row.get("TABLE_SCHEMA") or "")
        table_name = str(row.get("TABLE_NAME") or "")
        column_name = str(row.get("COLUMN_NAME") or "")
        if not schema_name or not table_name or not column_name:
            continue
        table_key = f"{schema_name.lower()}.{table_name.lower()}"
        columns_map.setdefault(table_key, []).append(column_name)
    return columns_map


def _get_table_row_count_map(connection: Any, table_names: list[str]) -> dict[str, int]:
    table_pairs = _collect_safe_table_pairs(table_names)
    if not table_pairs:
        return {}
    filter_sql, params = _build_table_filter_sql(table_pairs, "s.name", "t.name")
    rows = query_all(
        connection,
        f"""
        SELECT
            s.name AS schema_name,
            t.name AS table_name,
            COALESCE(SUM(p.rows), 0) AS total_rows
        FROM sys.tables AS t
        INNER JOIN sys.schemas AS s
            ON s.schema_id = t.schema_id
        LEFT JOIN sys.partitions AS p
            ON p.object_id = t.object_id
           AND p.index_id IN (0, 1)
        WHERE ({filter_sql})
        GROUP BY s.name, t.name;
        """,
        params,
    )
    row_count_map: dict[str, int] = {}
    for row in rows:
        schema_name = str(row.get("schema_name") or "")
        table_name = str(row.get("table_name") or "")
        if not schema_name or not table_name:
            continue
        table_key = f"{schema_name.lower()}.{table_name.lower()}"
        row_count_map[table_key] = _to_int(row.get("total_rows"), 0)
    return row_count_map


def _find_column_case_insensitive(columns: list[str], target_name: str) -> str | None:
    lookup = {col.lower(): col for col in columns}
    return lookup.get(target_name.lower())


def _find_first_existing_column(columns: list[str], candidates: list[str]) -> str | None:
    lookup = {col.lower(): col for col in columns}
    for candidate in candidates:
        found = lookup.get(candidate.lower())
        if found:
            return found
    return None


def _suggest_connection_fix(error_text: str) -> list[str]:
    suggestions: list[str] = []
    upper_error = error_text.upper()

    if "IM002" in upper_error:
        suggestions.append("Driver ODBC nao encontrado. Defina `ETL_SQL_DRIVER` para um driver instalado (ex.: `ODBC Driver 17 for SQL Server`).")
    if "08001" in upper_error or "SERVER DOES NOT EXIST" in upper_error:
        suggestions.append("Nao foi possivel conectar no servidor. Revise `ETL_SQL_SERVER` e `ETL_SQL_PORT`.")
    if "LOGIN FAILED" in upper_error or "28000" in upper_error:
        suggestions.append("Falha de autenticacao. Revise usuario/senha ou use `Trusted_Connection=yes`.")
    if "HYT00" in upper_error or "TIMEOUT" in upper_error:
        suggestions.append("Timeout de conexao. Verifique SQL Server ativo e firewall.")
    if "INVALID OBJECT NAME" in upper_error:
        suggestions.append("Objetos de controle nao existem no DW. Execute os scripts de `sql/dw/03_etl_control`.")
    if "CORE.CUSTOMERS" in upper_error:
        suggestions.append("Tabela de origem `core.customers` indisponivel. Execute bootstrap OLTP ou valide permissoes no OLTP.")
    if "CORE.PRODUCTS" in upper_error:
        suggestions.append("Tabela de origem `core.products` indisponivel. Execute bootstrap OLTP ou valide permissoes no OLTP.")
    if "CORE.DISCOUNT_CAMPAIGNS" in upper_error:
        suggestions.append("Tabela de origem `core.discount_campaigns` indisponivel. Execute bootstrap OLTP ou valide permissoes no OLTP.")
    if "CORE.REGIONS" in upper_error:
        suggestions.append("Tabela de origem `core.regions` indisponivel. Execute bootstrap OLTP ou valide permissoes no OLTP.")
    if "PERMISSION" in upper_error or "DENIED" in upper_error:
        suggestions.append("Permissao insuficiente para consulta. Revise grants do usuario de monitoramento.")

    if not suggestions:
        suggestions.append("Revise a string de conexao e confirme que os scripts SQL de controle ETL foram executados.")

    return suggestions


def _extract_constraint_name(error_text: str) -> str | None:
    match = re.search(r'constraint\s+"([^"]+)"', error_text, flags=re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return None


def _extract_object_name(error_text: str) -> str | None:
    match = re.search(r"object\s+'([^']+)'", error_text, flags=re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return None


def _extract_column_name(error_text: str) -> str | None:
    match = re.search(r"column\s+'([^']+)'", error_text, flags=re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return None


def _compact_error_signature(error_text: str, limit: int = 140) -> str:
    compact = " ".join(str(error_text or "").split())
    if len(compact) <= limit:
        return compact
    return compact[: limit - 3] + "..."


def _classify_error_message(error_message: Any) -> dict[str, str]:
    text = str(error_message or "").strip()
    if not text:
        return {
            "error_category": "sem_mensagem",
            "error_reason": "Falha sem mensagem detalhada.",
            "suggested_action": "Reexecutar com logs detalhados e revisar audit.etl_run_entity.",
            "error_signature": "(sem mensagem)",
        }

    upper_text = text.upper()
    constraint_name = _extract_constraint_name(text)
    object_name = _extract_object_name(text)
    column_name = _extract_column_name(text)

    if "ENTIDADE '" in upper_text and "CTL.ETL_CONTROL" in upper_text:
        return {
            "error_category": "config_controle",
            "error_reason": "Entidade inativa ou ausente no ctl.etl_control.",
            "suggested_action": "Cadastrar/ativar a entidade em ctl.etl_control e validar source/target.",
            "error_signature": _compact_error_signature(text),
        }

    if "CHECK CONSTRAINT" in upper_text or "CK_" in upper_text:
        detail = f" ({constraint_name})" if constraint_name else ""
        if column_name:
            detail += f" coluna {column_name}"
        return {
            "error_category": "constraint_check",
            "error_reason": f"Violacao de regra de dominio (CHECK){detail}.",
            "suggested_action": "Ajustar normalizacao/transformacao para respeitar dominio da coluna.",
            "error_signature": _compact_error_signature(text),
        }

    if "FOREIGN KEY CONSTRAINT" in upper_text or "FK_" in upper_text:
        detail = f" ({constraint_name})" if constraint_name else ""
        return {
            "error_category": "constraint_fk",
            "error_reason": f"Chave estrangeira invalida{detail}.",
            "suggested_action": "Garantir carga da dimensao pai antes da filha e revisar lookups de chave.",
            "error_signature": _compact_error_signature(text),
        }

    if (
        "UNIQUE CONSTRAINT" in upper_text
        or "DUPLICATE KEY" in upper_text
        or "CANNOT INSERT DUPLICATE KEY" in upper_text
        or "UQ_" in upper_text
    ):
        detail = f" ({constraint_name})" if constraint_name else ""
        return {
            "error_category": "constraint_unique",
            "error_reason": f"Duplicidade em chave unica{detail}.",
            "suggested_action": "Revisar chave natural, deduplicacao e logica de MERGE/upsert.",
            "error_signature": _compact_error_signature(text),
        }

    if "PERMISSION" in upper_text or "DENIED" in upper_text:
        target = f" no objeto {object_name}" if object_name else ""
        return {
            "error_category": "permissao",
            "error_reason": f"Permissao insuficiente{target}.",
            "suggested_action": "Aplicar GRANT necessario ao usuario tecnico (etl_monitor).",
            "error_signature": _compact_error_signature(text),
        }

    if "INVALID OBJECT NAME" in upper_text:
        return {
            "error_category": "objeto_ausente",
            "error_reason": "Objeto SQL ausente no banco alvo/origem.",
            "suggested_action": "Executar scripts DDL/contrato da entidade e validar schema.",
            "error_signature": _compact_error_signature(text),
        }

    if "HYT00" in upper_text or "TIMEOUT" in upper_text:
        return {
            "error_category": "timeout",
            "error_reason": "Tempo limite excedido na operacao SQL.",
            "suggested_action": "Aumentar timeout, reduzir batch e verificar performance/lock.",
            "error_signature": _compact_error_signature(text),
        }

    if "IM002" in upper_text:
        return {
            "error_category": "driver",
            "error_reason": "Driver ODBC nao encontrado no ambiente.",
            "suggested_action": "Configurar ETL_SQL_DRIVER com driver instalado (ODBC 17/18).",
            "error_signature": _compact_error_signature(text),
        }

    if "08001" in upper_text or "SERVER DOES NOT EXIST" in upper_text:
        return {
            "error_category": "conexao",
            "error_reason": "Falha de conexao com o SQL Server.",
            "suggested_action": "Validar host/porta, disponibilidade da instancia e firewall.",
            "error_signature": _compact_error_signature(text),
        }

    if "LOGIN FAILED" in upper_text or "28000" in upper_text:
        return {
            "error_category": "autenticacao",
            "error_reason": "Credenciais invalidas para conexao SQL.",
            "suggested_action": "Revisar usuario/senha e permissoes do login tecnico.",
            "error_signature": _compact_error_signature(text),
        }

    if "CONVERSION" in upper_text or "CAST" in upper_text or "TYPEERROR" in upper_text:
        return {
            "error_category": "conversao",
            "error_reason": "Erro de conversao de tipo durante transformacao/carga.",
            "suggested_action": "Ajustar cast/normalizacao e tratar nulos/formatos invalidos.",
            "error_signature": _compact_error_signature(text),
        }

    if "DEADLOCK" in upper_text:
        return {
            "error_category": "deadlock",
            "error_reason": "Conflito concorrente (deadlock) na execucao.",
            "suggested_action": "Reexecutar com retry e ajustar ordem/transacao de escrita.",
            "error_signature": _compact_error_signature(text),
        }

    return {
        "error_category": "outros",
        "error_reason": "Falha nao classificada automaticamente.",
        "suggested_action": "Inspecionar a mensagem tecnica e criar regra de classificacao especifica.",
        "error_signature": _compact_error_signature(text),
    }


def _enrich_failure_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty or "error_message" not in df.columns:
        return df

    enriched = df.copy()
    diagnostics = enriched["error_message"].apply(_classify_error_message).apply(pd.Series)
    for col in diagnostics.columns:
        enriched[col] = diagnostics[col]
    return enriched


def _fetch_df(sql: str, params: tuple[Any, ...] = ()) -> pd.DataFrame:
    config = ETLConfig.from_env()
    connection = None
    try:
        connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        rows = query_all(connection, sql, params)
        return _to_dataframe(rows)
    finally:
        close_quietly(connection)


def _capture_connection_snapshot(connection: Any) -> None:
    try:
        execute(connection, "EXEC audit.sp_capture_connection_snapshot;")
        connection.commit()
    except Exception:  # noqa: BLE001
        connection.rollback()


def capture_connection_snapshot_now() -> tuple[bool, str | None]:
    config = ETLConfig.from_env()
    connection = None
    try:
        connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        _capture_connection_snapshot(connection)
        return True, None
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)
    finally:
        close_quietly(connection)


@st.cache_data(ttl=20)
def get_preflight_snapshot() -> dict[str, Any]:
    config = ETLConfig.from_env()
    snapshot: dict[str, Any] = {
        "connection_ok": False,
        "ready_for_monitoring": False,
        "ready_for_first_run": False,
        "ready_for_all_active": False,
        "db_name": None,
        "server_name": None,
        "driver": _extract_conn_attr(config.dw_conn_str, "Driver"),
        "masked_conn_str": _mask_conn_str(config.dw_conn_str),
        "has_schema_ctl": False,
        "has_schema_audit": False,
        "has_ctl_etl_control": False,
        "has_audit_etl_run": False,
        "has_audit_etl_run_entity": False,
        "oltp_connection_ok": False,
        "control_entities": 0,
        "active_entities": 0,
        "inactive_entities": 0,
        "active_entities_ready": 0,
        "entity_checks": [],
        "invalid_mapping_entities": [],
        "missing_source_tables": [],
        "missing_target_tables": [],
        "run_count": 0,
        "error": None,
        "oltp_error": None,
        "suggestions": [],
    }

    connection = None
    oltp_connection = None
    try:
        connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        snapshot["connection_ok"] = True
        _capture_connection_snapshot(connection)

        base_info_sql = """
        SELECT
            DB_NAME() AS db_name,
            @@SERVERNAME AS server_name,
            CASE WHEN SCHEMA_ID('ctl') IS NOT NULL THEN 1 ELSE 0 END AS has_schema_ctl,
            CASE WHEN SCHEMA_ID('audit') IS NOT NULL THEN 1 ELSE 0 END AS has_schema_audit,
            CASE WHEN OBJECT_ID('ctl.etl_control', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_ctl_etl_control,
            CASE WHEN OBJECT_ID('audit.etl_run', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_audit_etl_run,
            CASE WHEN OBJECT_ID('audit.etl_run_entity', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_audit_etl_run_entity;
        """
        base_info = query_one(connection, base_info_sql)
        if base_info is None:
            raise RuntimeError("Falha ao executar preflight no DW.")

        snapshot["db_name"] = base_info.get("db_name")
        snapshot["server_name"] = base_info.get("server_name")
        snapshot["has_schema_ctl"] = _to_bool(base_info.get("has_schema_ctl"))
        snapshot["has_schema_audit"] = _to_bool(base_info.get("has_schema_audit"))
        snapshot["has_ctl_etl_control"] = _to_bool(base_info.get("has_ctl_etl_control"))
        snapshot["has_audit_etl_run"] = _to_bool(base_info.get("has_audit_etl_run"))
        snapshot["has_audit_etl_run_entity"] = _to_bool(base_info.get("has_audit_etl_run_entity"))

        if snapshot["has_ctl_etl_control"]:
            control_counts = query_one(
                connection,
                """
                SELECT
                    COUNT(*) AS control_entities,
                    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_entities
                FROM ctl.etl_control;
                """,
            )
            if control_counts:
                snapshot["control_entities"] = _to_int(control_counts.get("control_entities"), 0)
                snapshot["active_entities"] = _to_int(control_counts.get("active_entities"), 0)
                snapshot["inactive_entities"] = max(
                    0,
                    snapshot["control_entities"] - snapshot["active_entities"],
                )

        if snapshot["has_audit_etl_run"]:
            run_counts = query_one(connection, "SELECT COUNT(*) AS run_count FROM audit.etl_run;")
            if run_counts:
                snapshot["run_count"] = _to_int(run_counts.get("run_count"), 0)

        try:
            oltp_connection = connect_sqlserver(
                config.oltp_conn_str,
                command_timeout_seconds=config.command_timeout_seconds,
            )
            snapshot["oltp_connection_ok"] = True
        except Exception as exc:  # noqa: BLE001
            snapshot["oltp_error"] = str(exc)

        snapshot["ready_for_monitoring"] = (
            snapshot["connection_ok"]
            and snapshot["has_schema_ctl"]
            and snapshot["has_schema_audit"]
            and snapshot["has_ctl_etl_control"]
            and snapshot["has_audit_etl_run"]
            and snapshot["has_audit_etl_run_entity"]
        )
        if snapshot["has_ctl_etl_control"]:
            control_rows = query_all(
                connection,
                """
                SELECT
                    entity_name,
                    is_active,
                    source_table,
                    target_table
                FROM ctl.etl_control
                ORDER BY entity_name;
                """,
            )
            source_tables = [str(row.get("source_table") or "") for row in control_rows]
            target_tables = [str(row.get("target_table") or "") for row in control_rows]
            dw_existing_targets = _get_existing_tables(connection, target_tables)
            oltp_existing_sources = (
                _get_existing_tables(oltp_connection, source_tables)
                if snapshot["oltp_connection_ok"] and oltp_connection is not None
                else set()
            )

            entity_checks: list[dict[str, Any]] = []
            invalid_mapping_entities: list[str] = []
            missing_source_tables: list[str] = []
            missing_target_tables: list[str] = []
            active_ready_count = 0

            for row in control_rows:
                entity_name = str(row.get("entity_name") or "")
                is_active = _to_bool(row.get("is_active"))
                source_table = str(row.get("source_table") or "")
                target_table = str(row.get("target_table") or "")

                source_key = _normalize_table_key(source_table)
                target_key = _normalize_table_key(target_table)
                mapping_ok = source_key is not None and target_key is not None
                source_exists = bool(
                    source_key is not None
                    and snapshot["oltp_connection_ok"]
                    and source_key in oltp_existing_sources
                )
                target_exists = bool(target_key is not None and target_key in dw_existing_targets)
                ready = bool(
                    snapshot["ready_for_monitoring"]
                    and is_active
                    and mapping_ok
                    and target_exists
                    and snapshot["oltp_connection_ok"]
                    and source_exists
                )

                if is_active and not mapping_ok:
                    invalid_mapping_entities.append(entity_name)
                if is_active and mapping_ok and snapshot["oltp_connection_ok"] and not source_exists:
                    missing_source_tables.append(source_table)
                if is_active and mapping_ok and not target_exists:
                    missing_target_tables.append(target_table)
                if ready:
                    active_ready_count += 1

                entity_checks.append(
                    {
                        "entity_name": entity_name,
                        "is_active": is_active,
                        "source_table": source_table,
                        "target_table": target_table,
                        "mapping_ok": mapping_ok,
                        "source_exists": source_exists,
                        "target_exists": target_exists,
                        "ready": ready,
                    }
                )

            snapshot["entity_checks"] = entity_checks
            snapshot["invalid_mapping_entities"] = sorted(set(invalid_mapping_entities))
            snapshot["missing_source_tables"] = sorted({table for table in missing_source_tables if table})
            snapshot["missing_target_tables"] = sorted({table for table in missing_target_tables if table})
            snapshot["active_entities_ready"] = active_ready_count

        snapshot["ready_for_first_run"] = snapshot["active_entities_ready"] > 0
        snapshot["ready_for_all_active"] = bool(
            snapshot["active_entities"] > 0
            and snapshot["active_entities_ready"] == snapshot["active_entities"]
        )

        if snapshot["active_entities"] == 0:
            snapshot["suggestions"].append("Nao ha entidades ativas no ctl.etl_control. Ative pelo menos uma pipeline.")
        if snapshot["invalid_mapping_entities"]:
            snapshot["suggestions"].append(
                "Existem entidades ativas com source_table/target_table invalidos no ctl.etl_control."
            )
        if snapshot["missing_target_tables"]:
            snapshot["suggestions"].append("Existem tabelas de destino ausentes no DW para entidades ativas.")
        if snapshot["oltp_connection_ok"] and snapshot["missing_source_tables"]:
            snapshot["suggestions"].append("Existem tabelas de origem ausentes no OLTP para entidades ativas.")
        if not snapshot["oltp_connection_ok"] and snapshot["ready_for_monitoring"]:
            snapshot["suggestions"].append("Conexao OLTP indisponivel: validacao de origem ficou pendente.")

    except Exception as exc:  # noqa: BLE001
        error_text = str(exc)
        snapshot["error"] = error_text
        snapshot["suggestions"] = _suggest_connection_fix(error_text)
    finally:
        close_quietly(connection)
        close_quietly(oltp_connection)

    return snapshot


def _status_badge(ok: bool) -> str:
    return "OK" if ok else "PENDENTE"


def _render_preflight(snapshot: dict[str, Any]) -> None:
    with st.expander("Pre-flight de monitoramento", expanded=True):
        st.caption("Checklist tecnico antes do primeiro run do ETL.")

        a, b, c, d = st.columns(4)
        a.metric("Conexao DW", _status_badge(bool(snapshot["connection_ok"])))
        b.metric("Conexao OLTP", _status_badge(bool(snapshot["oltp_connection_ok"])))
        c.metric(
            "Pipelines ativas prontas",
            f"{_to_int(snapshot.get('active_entities_ready'), 0)}/{_to_int(snapshot.get('active_entities'), 0)}",
        )
        d.metric("Escopo ativo validado", _status_badge(bool(snapshot.get("ready_for_all_active"))))

        details_left, details_right = st.columns(2)
        with details_left:
            st.write(f"- server: `{snapshot.get('server_name') or 'N/A'}`")
            st.write(f"- database: `{snapshot.get('db_name') or 'N/A'}`")
            st.write(f"- driver: `{snapshot.get('driver') or 'N/A'}`")
            st.write(f"- entities cadastradas: `{snapshot.get('control_entities', 0)}`")
            st.write(f"- entities ativas: `{snapshot.get('active_entities', 0)}`")
            st.write(f"- entities inativas: `{snapshot.get('inactive_entities', 0)}`")
            st.write(f"- runs historicos: `{snapshot.get('run_count', 0)}`")
            st.write(
                f"- mapping invalido (ativas): `{len(snapshot.get('invalid_mapping_entities', []))}`"
            )
            st.write(
                f"- tabelas origem ausentes: `{len(snapshot.get('missing_source_tables', []))}`"
            )
            st.write(
                f"- tabelas destino ausentes: `{len(snapshot.get('missing_target_tables', []))}`"
            )

        with details_right:
            st.write(f"- schema ctl: `{_status_badge(bool(snapshot['has_schema_ctl']))}`")
            st.write(f"- schema audit: `{_status_badge(bool(snapshot['has_schema_audit']))}`")
            st.write(f"- tabela ctl.etl_control: `{_status_badge(bool(snapshot['has_ctl_etl_control']))}`")
            st.write(f"- tabela audit.etl_run: `{_status_badge(bool(snapshot['has_audit_etl_run']))}`")
            st.write(f"- tabela audit.etl_run_entity: `{_status_badge(bool(snapshot['has_audit_etl_run_entity']))}`")

        entity_checks_df = pd.DataFrame(snapshot.get("entity_checks", []))
        if not entity_checks_df.empty:
            entity_checks_df["is_active"] = entity_checks_df["is_active"].apply(lambda x: "SIM" if _to_bool(x) else "NAO")
            entity_checks_df["mapping_ok"] = entity_checks_df["mapping_ok"].apply(lambda x: "OK" if bool(x) else "PENDENTE")
            entity_checks_df["source_exists"] = entity_checks_df["source_exists"].apply(lambda x: "OK" if bool(x) else "PENDENTE")
            entity_checks_df["target_exists"] = entity_checks_df["target_exists"].apply(lambda x: "OK" if bool(x) else "PENDENTE")
            entity_checks_df["ready"] = entity_checks_df["ready"].apply(lambda x: "SIM" if bool(x) else "NAO")
            st.markdown("**Validacao por entidade/fato**")
            st.dataframe(
                entity_checks_df[
                    [
                        "entity_name",
                        "is_active",
                        "mapping_ok",
                        "source_exists",
                        "target_exists",
                        "ready",
                        "source_table",
                        "target_table",
                    ]
                ],
                use_container_width=True,
                hide_index=True,
            )

        if snapshot.get("error"):
            st.error("Falha no pre-flight de conexao.")
            st.code(str(snapshot["error"]))
            for suggestion in snapshot.get("suggestions", []):
                st.write(f"- {suggestion}")
            st.write("String de conexao usada (mascarada):")
            st.code(str(snapshot.get("masked_conn_str", "")))
        elif snapshot.get("oltp_error"):
            st.warning("Conexao DW ok, mas houve falha de acesso no OLTP.")
            st.code(str(snapshot["oltp_error"]))
            for suggestion in _suggest_connection_fix(str(snapshot["oltp_error"])):
                st.write(f"- {suggestion}")

        if not snapshot.get("ready_for_monitoring"):
            st.warning("Monitoramento ainda nao pronto. Execute os scripts de controle ETL e revise a conexao.")
        elif _to_int(snapshot.get("active_entities"), 0) == 0:
            st.warning("Monitoramento pronto, mas nao ha entidades ativas no controle.")
        elif not snapshot.get("ready_for_first_run"):
            st.info("Monitoramento pronto, mas nenhuma entidade ativa esta pronta para execucao.")
        elif not snapshot.get("ready_for_all_active"):
            st.info(
                "Monitoramento pronto, com escopo parcialmente validado. "
                "Revise entidades ativas com estrutura pendente."
            )
        else:
            st.success("Pre-flight concluido. Ambiente pronto para executar e auditar o escopo ativo completo.")


@st.cache_data(ttl=5)
def get_runs(limit: int = 50) -> pd.DataFrame:
    query = """
    SELECT TOP (?)
        run_id,
        entities_requested,
        started_by,
        started_at,
        finished_at,
        status,
        entities_succeeded,
        entities_failed,
        error_message
    FROM audit.etl_run
    ORDER BY run_id DESC;
    """
    return _fetch_df(query, (limit,))


@st.cache_data(ttl=5)
def get_control_state() -> pd.DataFrame:
    query = """
    SELECT
        entity_name,
        source_table,
        target_table,
        watermark_updated_at,
        watermark_id,
        batch_size,
        cutoff_minutes,
        is_active,
        last_run_id,
        last_status,
        last_success_at,
        updated_at
    FROM ctl.etl_control
    ORDER BY entity_name;
    """
    return _fetch_df(query)


@st.cache_data(ttl=5)
def get_entity_runs(limit: int = 200) -> pd.DataFrame:
    query = """
    SELECT TOP (?)
        re.run_entity_id,
        re.run_id,
        re.entity_name,
        re.entity_started_at,
        re.entity_finished_at,
        re.status,
        re.extracted_count,
        re.upserted_count,
        re.soft_deleted_count,
        re.watermark_from_updated_at,
        re.watermark_from_id,
        re.watermark_to_updated_at,
        re.watermark_to_id,
        re.error_message
    FROM audit.etl_run_entity AS re
    ORDER BY re.run_entity_id DESC;
    """
    return _fetch_df(query, (limit,))


@st.cache_data(ttl=5)
def get_run_entity_details(run_id: int) -> pd.DataFrame:
    query = """
    SELECT
        run_entity_id,
        run_id,
        entity_name,
        entity_started_at,
        entity_finished_at,
        status,
        extracted_count,
        upserted_count,
        soft_deleted_count,
        watermark_from_updated_at,
        watermark_from_id,
        watermark_to_updated_at,
        watermark_to_id,
        error_message
    FROM audit.etl_run_entity
    WHERE run_id = ?
    ORDER BY entity_name;
    """
    return _fetch_df(query, (int(run_id),))


@st.cache_data(ttl=5)
def get_daily_run_summary(days: int = 14) -> pd.DataFrame:
    query = """
    SELECT
        CAST(started_at AS DATE) AS run_date,
        status,
        COUNT(*) AS total_runs
    FROM audit.etl_run
    WHERE started_at >= DATEADD(DAY, -?, SYSUTCDATETIME())
    GROUP BY CAST(started_at AS DATE), status
    ORDER BY run_date ASC;
    """
    return _fetch_df(query, (int(days),))


@st.cache_data(ttl=5)
def get_entity_volume(days: int = 14) -> pd.DataFrame:
    query = """
    SELECT
        re.entity_name,
        SUM(re.extracted_count) AS extracted_total,
        SUM(re.upserted_count) AS upserted_total
    FROM audit.etl_run_entity AS re
    INNER JOIN audit.etl_run AS r
        ON r.run_id = re.run_id
    WHERE r.started_at >= DATEADD(DAY, -?, SYSUTCDATETIME())
    GROUP BY re.entity_name
    ORDER BY re.entity_name;
    """
    return _fetch_df(query, (int(days),))


@st.cache_data(ttl=5)
def get_execution_timeline(limit: int = 400) -> pd.DataFrame:
    query = """
    SELECT TOP (?)
        re.run_entity_id,
        re.run_id,
        re.entity_name,
        re.status,
        re.entity_started_at,
        re.entity_finished_at,
        re.extracted_count,
        re.upserted_count,
        re.soft_deleted_count,
        re.error_message,
        r.started_at AS run_started_at,
        r.status AS run_status,
        r.started_by
    FROM audit.etl_run_entity AS re
    INNER JOIN audit.etl_run AS r
        ON r.run_id = re.run_id
    ORDER BY re.run_entity_id DESC;
    """
    return _fetch_df(query, (int(limit),))


def _object_exists_table(connection: Any, table_name: str) -> bool:
    row = query_one(
        connection,
        "SELECT CASE WHEN OBJECT_ID(?, 'U') IS NOT NULL THEN 1 ELSE 0 END AS exists_flag;",
        (table_name,),
    )
    return _to_bool(row.get("exists_flag")) if row is not None else False


def _resolve_pipeline_status(row: dict[str, Any]) -> str:
    if not bool(row.get("source_exists")) or not bool(row.get("target_exists")):
        return "PENDENTE_ESTRUTURA"

    entity_last_status = str(row.get("entity_last_status") or "").lower()
    control_last_status = str(row.get("control_last_status") or "").lower()
    if entity_last_status == "running":
        return "RODANDO"
    if entity_last_status == "failed" or control_last_status == "failed":
        return "FALHA"
    if entity_last_status == "success" or control_last_status == "success":
        return "OK"
    return "SEM_EXECUCAO"


@st.cache_data(ttl=10)
def get_pipeline_overview() -> pd.DataFrame:
    query = """
    SELECT
        c.entity_name,
        c.is_active,
        c.source_table,
        c.target_table,
        c.source_pk_column,
        c.watermark_updated_at,
        c.watermark_id,
        c.last_status AS control_last_status,
        c.last_success_at,
        c.last_run_id,
        re.status AS entity_last_status,
        re.entity_started_at AS entity_last_started_at,
        re.entity_finished_at AS entity_last_finished_at,
        re.extracted_count AS entity_last_extracted,
        re.upserted_count AS entity_last_upserted,
        re.soft_deleted_count AS entity_last_soft_deleted,
        re.error_message AS entity_last_error
    FROM ctl.etl_control AS c
    OUTER APPLY
    (
        SELECT TOP (1)
            status,
            entity_started_at,
            entity_finished_at,
            extracted_count,
            upserted_count,
            soft_deleted_count,
            error_message
        FROM audit.etl_run_entity AS re
        WHERE re.entity_name = c.entity_name
        ORDER BY re.run_entity_id DESC
    ) AS re
    ORDER BY c.entity_name;
    """
    df = _fetch_df(query)
    if df.empty:
        return df

    config = ETLConfig.from_env()
    dw_connection = None
    oltp_connection = None
    try:
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )

        source_table_names = [str(value) for value in df["source_table"].tolist()]
        target_table_names = [str(value) for value in df["target_table"].tolist()]

        source_existing = _get_existing_tables(oltp_connection, source_table_names)
        target_existing = _get_existing_tables(dw_connection, target_table_names)
        source_columns_map = _get_table_columns_map(oltp_connection, source_table_names)
        target_columns_map = _get_table_columns_map(dw_connection, target_table_names)
        source_row_counts = _get_table_row_count_map(oltp_connection, source_table_names)
        target_row_counts = _get_table_row_count_map(dw_connection, target_table_names)

        source_exists: list[bool] = []
        target_exists: list[bool] = []
        source_totals: list[int] = []
        target_totals: list[int] = []
        pending_since_watermark: list[int] = []
        source_max_updated_list: list[Any] = []
        target_max_updated_list: list[Any] = []
        freshness_minutes_list: list[float | None] = []
        coverage_percent_list: list[float | None] = []
        duration_seconds_list: list[float | None] = []
        throughput_rows_per_sec_list: list[float | None] = []

        target_updated_candidates = [
            "data_ultima_atualizacao",
            "updated_at",
            "data_atualizacao",
            "data_carga",
            "dt_atualizacao",
            "load_at",
            "loaded_at",
        ]

        for _, row in df.iterrows():
            source_table = str(row["source_table"])
            target_table = str(row["target_table"])
            source_pk_column = str(row.get("source_pk_column") or "").strip()
            source_key = _normalize_table_key(source_table)
            target_key = _normalize_table_key(target_table)

            has_source = bool(source_key and source_key in source_existing)
            has_target = bool(target_key and target_key in target_existing)
            source_exists.append(has_source)
            target_exists.append(has_target)

            source_total = _to_int(source_row_counts.get(source_key) if source_key else 0, 0) if has_source else 0
            target_total = _to_int(target_row_counts.get(target_key) if target_key else 0, 0) if has_target else 0
            pending = 0
            source_max_updated_at = None
            target_max_updated_at = None

            if has_source:
                safe_source = _safe_qualified_name(source_table)
                source_columns = {
                    str(column_name).lower()
                    for column_name in source_columns_map.get(source_key or "", [])
                }
                if "updated_at" in source_columns:
                    source_max_row = query_one(
                        oltp_connection,
                        f"SELECT MAX(updated_at) AS max_updated_at FROM {safe_source};",
                    )
                    if source_max_row:
                        source_max_updated_at = source_max_row.get("max_updated_at")

                    if (
                        row.get("watermark_updated_at") is not None
                        and source_pk_column
                        and _is_safe_identifier(source_pk_column)
                        and source_pk_column.lower() in source_columns
                    ):
                        safe_pk = f"[{source_pk_column}]"
                        pending_row = query_one(
                            oltp_connection,
                            f"""
                            SELECT COUNT(*) AS pending_since_watermark
                            FROM {safe_source}
                            WHERE updated_at > ?
                               OR (updated_at = ? AND {safe_pk} > ?);
                            """,
                            (
                                row.get("watermark_updated_at"),
                                row.get("watermark_updated_at"),
                                _to_int(row.get("watermark_id"), 0),
                            ),
                        )
                        pending = _to_int(
                            pending_row.get("pending_since_watermark") if pending_row else 0,
                            0,
                        )

            if has_target:
                safe_target = _safe_qualified_name(target_table)
                target_columns = {
                    str(column_name).lower()
                    for column_name in target_columns_map.get(target_key or "", [])
                }
                target_updated_col = next(
                    (col for col in target_updated_candidates if col in target_columns),
                    None,
                )
                if target_updated_col is not None:
                    target_max_row = query_one(
                        dw_connection,
                        f"SELECT MAX([{target_updated_col}]) AS max_updated_at FROM {safe_target};",
                    )
                    if target_max_row:
                        target_max_updated_at = target_max_row.get("max_updated_at")

            source_totals.append(source_total)
            target_totals.append(target_total)
            pending_since_watermark.append(pending)
            source_max_updated_list.append(source_max_updated_at)
            target_max_updated_list.append(target_max_updated_at)
            coverage_percent_list.append(_safe_ratio(target_total, source_total))
            freshness_minutes_list.append(
                _compute_freshness_minutes(source_max_updated_at, target_max_updated_at),
            )

            started_at = row.get("entity_last_started_at")
            finished_at = row.get("entity_last_finished_at")
            if started_at is not None and finished_at is not None:
                duration_seconds = max(1.0, (finished_at - started_at).total_seconds())
                duration_seconds_list.append(duration_seconds)
                throughput_rows_per_sec_list.append(
                    _to_int(row.get("entity_last_upserted"), 0) / duration_seconds,
                )
            else:
                duration_seconds_list.append(None)
                throughput_rows_per_sec_list.append(None)

        df["source_exists"] = source_exists
        df["target_exists"] = target_exists
        df["source_total"] = source_totals
        df["target_total"] = target_totals
        df["source_pending_since_watermark"] = pending_since_watermark
        df["source_max_updated_at"] = source_max_updated_list
        df["target_max_updated_at"] = target_max_updated_list
        df["coverage_percent"] = coverage_percent_list
        df["freshness_minutes"] = freshness_minutes_list
        df["entity_last_duration_seconds"] = duration_seconds_list
        df["entity_last_throughput_rows_per_sec"] = throughput_rows_per_sec_list
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)

    records = df.to_dict("records")
    df["pipeline_status"] = [str(_resolve_pipeline_status(rec)) for rec in records]
    return df


@st.cache_data(ttl=5)
def get_running_runs() -> pd.DataFrame:
    query = """
    SELECT
        run_id,
        entities_requested,
        started_by,
        started_at,
        status
    FROM audit.etl_run
    WHERE status = 'running'
    ORDER BY run_id DESC;
    """
    return _fetch_df(query)


@st.cache_data(ttl=5)
def get_running_entities() -> pd.DataFrame:
    query = """
    SELECT
        re.run_entity_id,
        re.run_id,
        re.entity_name,
        re.entity_started_at,
        re.status,
        re.extracted_count,
        re.upserted_count,
        re.soft_deleted_count,
        re.watermark_from_updated_at,
        re.watermark_from_id
    FROM audit.etl_run_entity AS re
    WHERE re.status = 'running'
    ORDER BY re.entity_started_at DESC;
    """
    return _fetch_df(query)


def _get_table_columns(connection: Any, table_name: str) -> list[dict[str, Any]]:
    parsed = _parse_table_name(table_name)
    if parsed is None:
        return []
    schema_name, object_name = parsed
    rows = query_all(
        connection,
        """
        SELECT
            COLUMN_NAME,
            DATA_TYPE,
            IS_NULLABLE,
            ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = ?
          AND TABLE_NAME = ?
        ORDER BY ORDINAL_POSITION;
        """,
        (schema_name, object_name),
    )
    return rows


@st.cache_data(ttl=5)
def get_pipeline_health(entity_name: str) -> dict[str, Any]:
    config = ETLConfig.from_env()
    snapshot: dict[str, Any] = {
        "entity_name": entity_name,
        "is_active": False,
        "source_table": None,
        "target_table": None,
        "source_pk_column": None,
        "source_total": 0,
        "source_soft_deleted": 0,
        "source_pending_since_watermark": 0,
        "source_max_updated_at": None,
        "target_total": 0,
        "target_max_updated_at": None,
        "watermark_updated_at": None,
        "watermark_id": 0,
        "last_run_id": None,
        "last_status": None,
        "last_success_at": None,
        "last_entity_status": None,
        "last_entity_started_at": None,
        "last_entity_finished_at": None,
        "last_entity_extracted": 0,
        "last_entity_upserted": 0,
        "last_entity_soft_deleted": 0,
        "last_entity_error": None,
        "coverage_percent": None,
        "freshness_minutes": None,
        "last_duration_seconds": None,
        "last_throughput_rows_per_sec": None,
        "error": None,
    }

    dw_connection = None
    oltp_connection = None
    try:
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        control_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                entity_name,
                is_active,
                source_table,
                target_table,
                source_pk_column,
                watermark_updated_at,
                watermark_id,
                last_run_id,
                last_status,
                last_success_at
            FROM ctl.etl_control
            WHERE entity_name = ?;
            """,
            (entity_name,),
        )
        if control_row is None:
            raise ValueError(f"Entidade nao encontrada em ctl.etl_control: {entity_name}")

        snapshot["is_active"] = _to_bool(control_row.get("is_active"))
        snapshot["source_table"] = control_row.get("source_table")
        snapshot["target_table"] = control_row.get("target_table")
        snapshot["source_pk_column"] = control_row.get("source_pk_column")
        snapshot["watermark_updated_at"] = control_row.get("watermark_updated_at")
        snapshot["watermark_id"] = _to_int(control_row.get("watermark_id"), 0)
        snapshot["last_run_id"] = control_row.get("last_run_id")
        snapshot["last_status"] = control_row.get("last_status")
        snapshot["last_success_at"] = control_row.get("last_success_at")

        entity_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                status AS last_entity_status,
                entity_started_at AS last_entity_started_at,
                entity_finished_at AS last_entity_finished_at,
                extracted_count AS last_entity_extracted,
                upserted_count AS last_entity_upserted,
                soft_deleted_count AS last_entity_soft_deleted,
                error_message AS last_entity_error
            FROM audit.etl_run_entity
            WHERE entity_name = ?
            ORDER BY run_entity_id DESC;
            """,
            (entity_name,),
        )
        if entity_row:
            snapshot["last_entity_status"] = entity_row.get("last_entity_status")
            snapshot["last_entity_started_at"] = entity_row.get("last_entity_started_at")
            snapshot["last_entity_finished_at"] = entity_row.get("last_entity_finished_at")
            snapshot["last_entity_extracted"] = _to_int(entity_row.get("last_entity_extracted"), 0)
            snapshot["last_entity_upserted"] = _to_int(entity_row.get("last_entity_upserted"), 0)
            snapshot["last_entity_soft_deleted"] = _to_int(entity_row.get("last_entity_soft_deleted"), 0)
            snapshot["last_entity_error"] = entity_row.get("last_entity_error")

        source_table = str(snapshot.get("source_table") or "")
        target_table = str(snapshot.get("target_table") or "")
        source_pk_column = str(snapshot.get("source_pk_column") or "").strip()

        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )

        safe_source = _safe_qualified_name(source_table)
        safe_target = _safe_qualified_name(target_table)

        source_count_row = query_one(oltp_connection, f"SELECT COUNT(*) AS total FROM {safe_source};")
        if source_count_row:
            snapshot["source_total"] = _to_int(source_count_row.get("total"), 0)

        target_count_row = query_one(dw_connection, f"SELECT COUNT(*) AS total FROM {safe_target};")
        if target_count_row:
            snapshot["target_total"] = _to_int(target_count_row.get("total"), 0)

        source_columns = {str(col["COLUMN_NAME"]).lower() for col in _get_table_columns(oltp_connection, source_table)}
        target_columns = {str(col["COLUMN_NAME"]).lower() for col in _get_table_columns(dw_connection, target_table)}

        if "deleted_at" in source_columns:
            soft_row = query_one(
                oltp_connection,
                f"SELECT COUNT(*) AS total FROM {safe_source} WHERE deleted_at IS NOT NULL;",
            )
            if soft_row:
                snapshot["source_soft_deleted"] = _to_int(soft_row.get("total"), 0)

        if "updated_at" in source_columns:
            source_max_row = query_one(
                oltp_connection,
                f"SELECT MAX(updated_at) AS max_updated_at FROM {safe_source};",
            )
            if source_max_row:
                snapshot["source_max_updated_at"] = source_max_row.get("max_updated_at")

            safe_pk = f"[{source_pk_column}]" if _is_safe_identifier(source_pk_column) else None
            if safe_pk and source_pk_column.lower() in source_columns:
                pending_row = query_one(
                    oltp_connection,
                    f"""
                    SELECT
                        COUNT(*) AS pending_since_watermark
                    FROM {safe_source}
                    WHERE updated_at > ?
                       OR (updated_at = ? AND {safe_pk} > ?);
                    """,
                    (
                        snapshot["watermark_updated_at"],
                        snapshot["watermark_updated_at"],
                        snapshot["watermark_id"],
                    ),
                )
                if pending_row:
                    snapshot["source_pending_since_watermark"] = _to_int(
                        pending_row.get("pending_since_watermark"),
                        0,
                    )

        target_updated_col = None
        if "data_ultima_atualizacao" in target_columns:
            target_updated_col = "data_ultima_atualizacao"
        elif "updated_at" in target_columns:
            target_updated_col = "updated_at"

        if target_updated_col is not None:
            target_max_row = query_one(
                dw_connection,
                f"SELECT MAX([{target_updated_col}]) AS max_updated_at FROM {safe_target};",
            )
            if target_max_row:
                snapshot["target_max_updated_at"] = target_max_row.get("max_updated_at")

        source_total = _to_int(snapshot.get("source_total"), 0)
        target_total = _to_int(snapshot.get("target_total"), 0)
        snapshot["coverage_percent"] = _safe_ratio(target_total, source_total)
        snapshot["freshness_minutes"] = _compute_freshness_minutes(
            snapshot.get("source_max_updated_at"),
            snapshot.get("target_max_updated_at"),
        )

        started_at = snapshot.get("last_entity_started_at")
        finished_at = snapshot.get("last_entity_finished_at")
        if started_at is not None and finished_at is not None:
            duration_seconds = max(1.0, (finished_at - started_at).total_seconds())
            snapshot["last_duration_seconds"] = duration_seconds
            snapshot["last_throughput_rows_per_sec"] = _to_int(
                snapshot.get("last_entity_upserted"),
                0,
            ) / duration_seconds
    except Exception as exc:  # noqa: BLE001
        snapshot["error"] = str(exc)
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)

    return snapshot


@st.cache_data(ttl=5)
def get_pipeline_recent_source(entity_name: str, limit: int = 20) -> pd.DataFrame:
    config = ETLConfig.from_env()
    dw_connection = None
    oltp_connection = None
    try:
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        control_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                source_table,
                source_pk_column
            FROM ctl.etl_control
            WHERE entity_name = ?;
            """,
            (entity_name,),
        )
        if control_row is None:
            return pd.DataFrame()

        source_table = str(control_row.get("source_table") or "")
        source_pk_column = str(control_row.get("source_pk_column") or "").strip()
        safe_source = _safe_qualified_name(source_table)

        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )

        column_rows = _get_table_columns(oltp_connection, source_table)
        if not column_rows:
            return pd.DataFrame()

        ordered_columns = [str(col["COLUMN_NAME"]) for col in column_rows]
        lower_lookup = {name.lower(): name for name in ordered_columns}

        selected_columns: list[str] = []
        for candidate in [source_pk_column, "updated_at", "deleted_at", "created_at"]:
            key = candidate.lower()
            if key in lower_lookup:
                selected_columns.append(lower_lookup[key])

        for col_name in ordered_columns:
            if col_name in selected_columns:
                continue
            selected_columns.append(col_name)
            if len(selected_columns) >= 12:
                break

        selected_columns = selected_columns[:12]
        select_list = ", ".join([f"[{col}]" for col in selected_columns if _is_safe_identifier(col)])
        if not select_list:
            return pd.DataFrame()

        order_by_parts: list[str] = []
        if "updated_at" in lower_lookup:
            order_by_parts.append("[updated_at] DESC")
        if source_pk_column.lower() in lower_lookup and _is_safe_identifier(lower_lookup[source_pk_column.lower()]):
            order_by_parts.append(f"[{lower_lookup[source_pk_column.lower()]}] DESC")
        elif selected_columns:
            fallback = selected_columns[0]
            if _is_safe_identifier(fallback):
                order_by_parts.append(f"[{fallback}] DESC")

        order_by_clause = ", ".join(order_by_parts) if order_by_parts else "(SELECT NULL)"
        query = f"""
        SELECT TOP (?)
            {select_list}
        FROM {safe_source}
        ORDER BY {order_by_clause};
        """
        rows = query_all(oltp_connection, query, (int(limit),))
        return _to_dataframe(rows)
    except Exception:
        return pd.DataFrame()
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)


@st.cache_data(ttl=5)
def get_pipeline_quality_snapshot(entity_name: str) -> dict[str, Any]:
    snapshot: dict[str, Any] = {
        "entity_name": entity_name,
        "checks": [],
        "ok_count": 0,
        "warning_count": 0,
        "alert_count": 0,
        "error": None,
    }

    config = ETLConfig.from_env()
    dw_connection = None
    oltp_connection = None
    try:
        health = get_pipeline_health(entity_name)
        if health.get("error"):
            raise RuntimeError(str(health["error"]))

        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )

        control_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                source_table,
                target_table,
                source_pk_column
            FROM ctl.etl_control
            WHERE entity_name = ?;
            """,
            (entity_name,),
        )
        if control_row is None:
            raise RuntimeError(f"Entidade nao encontrada em ctl.etl_control: {entity_name}")

        source_table = str(control_row.get("source_table") or "")
        target_table = str(control_row.get("target_table") or "")
        source_pk_column = str(control_row.get("source_pk_column") or "").strip()
        safe_source = _safe_qualified_name(source_table)
        safe_target = _safe_qualified_name(target_table)

        source_column_rows = _get_table_columns(oltp_connection, source_table)
        target_column_rows = _get_table_columns(dw_connection, target_table)
        source_columns = [str(col["COLUMN_NAME"]) for col in source_column_rows]
        target_columns = [str(col["COLUMN_NAME"]) for col in target_column_rows]

        def add_check(check: str, status: str, value: Any, detail: str) -> None:
            snapshot["checks"].append(
                {
                    "check": check,
                    "status": status,
                    "valor": str(value),
                    "detalhe": detail,
                }
            )

        coverage = health.get("coverage_percent")
        add_check(
            "cobertura_oltp_dw",
            "OK" if (coverage or 0) >= 95 else "ATENCAO",
            _format_ratio(coverage),
            "Razao target_total/source_total do pipeline.",
        )

        pending = _to_int(health.get("source_pending_since_watermark"), 0)
        add_check(
            "pendencia_incremental",
            "OK" if pending == 0 else "ATENCAO",
            pending,
            "Registros na origem apos watermark atual.",
        )

        source_pk = _find_column_case_insensitive(source_columns, source_pk_column)
        if source_pk and _is_safe_identifier(source_pk):
            source_null_pk = query_one(
                oltp_connection,
                f"SELECT COUNT(*) AS total FROM {safe_source} WHERE [{source_pk}] IS NULL;",
            )
            source_null_pk_count = _to_int(source_null_pk.get("total") if source_null_pk else 0, 0)
            add_check(
                "fonte_pk_nulos",
                "OK" if source_null_pk_count == 0 else "ALERTA",
                source_null_pk_count,
                f"Nulos na coluna chave da origem: {source_pk}.",
            )

        target_natural_key = None
        for col in target_columns:
            if col.lower().endswith("_original_id"):
                target_natural_key = col
                break
        if target_natural_key is None:
            target_natural_key = _find_column_case_insensitive(target_columns, source_pk_column)

        if target_natural_key and _is_safe_identifier(target_natural_key):
            target_null_nk = query_one(
                dw_connection,
                f"SELECT COUNT(*) AS total FROM {safe_target} WHERE [{target_natural_key}] IS NULL;",
            )
            target_null_nk_count = _to_int(target_null_nk.get("total") if target_null_nk else 0, 0)
            add_check(
                "alvo_chave_natural_nulos",
                "OK" if target_null_nk_count == 0 else "ALERTA",
                target_null_nk_count,
                f"Nulos da chave natural no DW: {target_natural_key}.",
            )

            target_dup_nk = query_one(
                dw_connection,
                f"""
                SELECT COUNT(*) AS total_dup
                FROM
                (
                    SELECT [{target_natural_key}]
                    FROM {safe_target}
                    GROUP BY [{target_natural_key}]
                    HAVING COUNT(*) > 1
                ) AS d;
                """,
            )
            target_dup_nk_count = _to_int(target_dup_nk.get("total_dup") if target_dup_nk else 0, 0)
            add_check(
                "alvo_chave_natural_duplicada",
                "OK" if target_dup_nk_count == 0 else "ALERTA",
                target_dup_nk_count,
                f"Duplicidades da chave natural no DW: {target_natural_key}.",
            )

        target_updated_col = _find_first_existing_column(
            target_columns,
            [
                "data_ultima_atualizacao",
                "updated_at",
                "data_atualizacao",
                "data_carga",
                "dt_atualizacao",
                "load_at",
                "loaded_at",
            ],
        )
        if target_updated_col and _is_safe_identifier(target_updated_col):
            target_null_updated = query_one(
                dw_connection,
                f"SELECT COUNT(*) AS total FROM {safe_target} WHERE [{target_updated_col}] IS NULL;",
            )
            target_null_updated_count = _to_int(target_null_updated.get("total") if target_null_updated else 0, 0)
            add_check(
                "alvo_updated_nulos",
                "OK" if target_null_updated_count == 0 else "ATENCAO",
                target_null_updated_count,
                f"Nulos da coluna de atualizacao no DW: {target_updated_col}.",
            )

        target_status_col = _find_column_case_insensitive(target_columns, "situacao")
        if target_status_col and _is_safe_identifier(target_status_col):
            invalid_status = query_one(
                dw_connection,
                f"""
                SELECT COUNT(*) AS total
                FROM {safe_target}
                WHERE [{target_status_col}] IS NOT NULL
                  AND [{target_status_col}] NOT IN ('Ativo', 'Inativo', 'Descontinuado');
                """,
            )
            invalid_status_count = _to_int(invalid_status.get("total") if invalid_status else 0, 0)
            add_check(
                "alvo_status_invalido",
                "OK" if invalid_status_count == 0 else "ATENCAO",
                invalid_status_count,
                f"Valores fora do dominio esperado em {target_status_col}.",
            )

        source_soft_deleted = _to_int(health.get("source_soft_deleted"), 0)
        target_soft_deleted_proxy = None
        target_inactive_col = _find_column_case_insensitive(target_columns, "eh_ativo")
        if target_status_col and _is_safe_identifier(target_status_col):
            inactive_row = query_one(
                dw_connection,
                f"""
                SELECT COUNT(*) AS total
                FROM {safe_target}
                WHERE [{target_status_col}] IN ('Inativo', 'Descontinuado');
                """,
            )
            target_soft_deleted_proxy = _to_int(inactive_row.get("total") if inactive_row else 0, 0)
        elif target_inactive_col and _is_safe_identifier(target_inactive_col):
            inactive_row = query_one(
                dw_connection,
                f"SELECT COUNT(*) AS total FROM {safe_target} WHERE [{target_inactive_col}] = 0;",
            )
            target_soft_deleted_proxy = _to_int(inactive_row.get("total") if inactive_row else 0, 0)

        if target_soft_deleted_proxy is not None:
            delta_soft_delete = abs(target_soft_deleted_proxy - source_soft_deleted)
            tolerance = max(5, int(source_soft_deleted * 0.10))
            add_check(
                "reconciliacao_soft_delete",
                "OK" if delta_soft_delete <= tolerance else "ATENCAO",
                f"fonte={source_soft_deleted} | alvo={target_soft_deleted_proxy}",
                f"Diferenca absoluta={delta_soft_delete} (tolerancia={tolerance}).",
            )

        target_parsed = _parse_table_name(target_table)
        target_schema = target_parsed[0].lower() if target_parsed is not None else ""
        is_fact_pipeline = entity_name.lower().startswith("fact_") or target_schema == "fact"
        if is_fact_pipeline:
            target_natural_key_lower = (
                target_natural_key.lower()
                if target_natural_key is not None and _is_safe_identifier(target_natural_key)
                else None
            )

            required_id_columns: list[str] = []
            for col in target_column_rows:
                column_name = str(col.get("COLUMN_NAME") or "")
                is_nullable = str(col.get("IS_NULLABLE") or "").upper()
                if (
                    column_name
                    and column_name.lower().endswith("_id")
                    and is_nullable == "NO"
                    and _is_safe_identifier(column_name)
                    and column_name.lower() != target_natural_key_lower
                ):
                    required_id_columns.append(column_name)

            if required_id_columns:
                null_sum_parts = [
                    f"SUM(CASE WHEN [{column_name}] IS NULL THEN 1 ELSE 0 END) AS [{column_name}__nulls]"
                    for column_name in required_id_columns
                ]
                null_counts_row = query_one(
                    dw_connection,
                    f"""
                    SELECT
                        {", ".join(null_sum_parts)}
                    FROM {safe_target};
                    """,
                )
                null_offenders: list[str] = []
                total_required_id_nulls = 0
                if null_counts_row is not None:
                    for column_name in required_id_columns:
                        key = f"{column_name}__nulls"
                        null_count = _to_int(null_counts_row.get(key), 0)
                        total_required_id_nulls += null_count
                        if null_count > 0:
                            null_offenders.append(f"{column_name}={null_count}")

                add_check(
                    "fato_fk_obrigatoria_nula",
                    "OK" if total_required_id_nulls == 0 else "ALERTA",
                    total_required_id_nulls,
                    "Nulos em colunas *_id obrigatorias no fato."
                    if not null_offenders
                    else "Nulos em: " + ", ".join(null_offenders[:4]),
                )

            numeric_types = {
                "tinyint",
                "smallint",
                "int",
                "bigint",
                "decimal",
                "numeric",
                "float",
                "real",
                "money",
                "smallmoney",
            }
            metric_columns: list[str] = []
            for col in target_column_rows:
                column_name = str(col.get("COLUMN_NAME") or "")
                data_type = str(col.get("DATA_TYPE") or "").lower()
                if (
                    column_name
                    and _is_safe_identifier(column_name)
                    and data_type in numeric_types
                    and (
                        column_name.lower().startswith("valor_")
                        or column_name.lower().startswith("quantidade_")
                        or column_name.lower().startswith("percentual_")
                    )
                ):
                    metric_columns.append(column_name)

            if metric_columns:
                negative_sum_parts = [
                    f"SUM(CASE WHEN [{column_name}] < 0 THEN 1 ELSE 0 END) AS [{column_name}__neg]"
                    for column_name in metric_columns
                ]
                negative_counts_row = query_one(
                    dw_connection,
                    f"""
                    SELECT
                        {", ".join(negative_sum_parts)}
                    FROM {safe_target};
                    """,
                )
                negative_offenders: list[str] = []
                total_negative_values = 0
                if negative_counts_row is not None:
                    for column_name in metric_columns:
                        key = f"{column_name}__neg"
                        negative_count = _to_int(negative_counts_row.get(key), 0)
                        total_negative_values += negative_count
                        if negative_count > 0:
                            negative_offenders.append(f"{column_name}={negative_count}")

                add_check(
                    "fato_metricas_negativas",
                    "OK" if total_negative_values == 0 else "ALERTA",
                    total_negative_values,
                    "Valores negativos nas metricas numericas do fato."
                    if not negative_offenders
                    else "Negativos em: " + ", ".join(negative_offenders[:4]),
                )

        for row in snapshot["checks"]:
            status = str(row.get("status") or "")
            if status == "OK":
                snapshot["ok_count"] += 1
            elif status == "ATENCAO":
                snapshot["warning_count"] += 1
            elif status == "ALERTA":
                snapshot["alert_count"] += 1
    except Exception as exc:  # noqa: BLE001
        snapshot["error"] = str(exc)
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)

    return snapshot


@st.cache_data(ttl=5)
def get_dim_cliente_health() -> dict[str, Any]:
    config = ETLConfig.from_env()
    snapshot: dict[str, Any] = {
        "source_total": 0,
        "source_soft_deleted": 0,
        "source_pending_since_watermark": 0,
        "source_max_updated_at": None,
        "target_total": 0,
        "target_active": 0,
        "target_vip": 0,
        "target_no_email": 0,
        "target_invalid_state": 0,
        "target_max_updated_at": None,
        "watermark_updated_at": None,
        "watermark_id": 0,
        "last_run_id": None,
        "last_status": None,
        "last_success_at": None,
        "last_entity_status": None,
        "last_entity_finished_at": None,
        "error": None,
    }

    dw_connection = None
    oltp_connection = None
    try:
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        target_row = query_one(
            dw_connection,
            """
            SELECT
                COUNT(*) AS target_total,
                SUM(CASE WHEN eh_ativo = 1 THEN 1 ELSE 0 END) AS target_active,
                SUM(CASE WHEN eh_cliente_vip = 1 THEN 1 ELSE 0 END) AS target_vip,
                SUM(CASE WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 1 ELSE 0 END) AS target_no_email,
                SUM(CASE WHEN estado IS NULL OR LEN(estado) <> 2 THEN 1 ELSE 0 END) AS target_invalid_state,
                MAX(data_ultima_atualizacao) AS target_max_updated_at
            FROM dim.DIM_CLIENTE;
            """,
        )
        if target_row:
            snapshot["target_total"] = _to_int(target_row.get("target_total"), 0)
            snapshot["target_active"] = _to_int(target_row.get("target_active"), 0)
            snapshot["target_vip"] = _to_int(target_row.get("target_vip"), 0)
            snapshot["target_no_email"] = _to_int(target_row.get("target_no_email"), 0)
            snapshot["target_invalid_state"] = _to_int(target_row.get("target_invalid_state"), 0)
            snapshot["target_max_updated_at"] = target_row.get("target_max_updated_at")

        control_row = query_one(
            dw_connection,
            """
            SELECT
                watermark_updated_at,
                watermark_id,
                last_run_id,
                last_status,
                last_success_at
            FROM ctl.etl_control
            WHERE entity_name = 'dim_cliente';
            """,
        )
        if control_row:
            snapshot["watermark_updated_at"] = control_row.get("watermark_updated_at")
            snapshot["watermark_id"] = _to_int(control_row.get("watermark_id"), 0)
            snapshot["last_run_id"] = control_row.get("last_run_id")
            snapshot["last_status"] = control_row.get("last_status")
            snapshot["last_success_at"] = control_row.get("last_success_at")

        entity_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                status AS last_entity_status,
                entity_finished_at AS last_entity_finished_at
            FROM audit.etl_run_entity
            WHERE entity_name = 'dim_cliente'
            ORDER BY run_entity_id DESC;
            """,
        )
        if entity_row:
            snapshot["last_entity_status"] = entity_row.get("last_entity_status")
            snapshot["last_entity_finished_at"] = entity_row.get("last_entity_finished_at")

        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        source_row = query_one(
            oltp_connection,
            """
            SELECT
                COUNT(*) AS source_total,
                SUM(CASE WHEN deleted_at IS NOT NULL THEN 1 ELSE 0 END) AS source_soft_deleted,
                MAX(updated_at) AS source_max_updated_at
            FROM core.customers;
            """,
        )
        if source_row:
            snapshot["source_total"] = _to_int(source_row.get("source_total"), 0)
            snapshot["source_soft_deleted"] = _to_int(source_row.get("source_soft_deleted"), 0)
            snapshot["source_max_updated_at"] = source_row.get("source_max_updated_at")

        if snapshot["watermark_updated_at"] is not None:
            pending_row = query_one(
                oltp_connection,
                """
                SELECT
                    COUNT(*) AS pending_since_watermark
                FROM core.customers
                WHERE updated_at > ?
                   OR (updated_at = ? AND customer_id > ?);
                """,
                (
                    snapshot["watermark_updated_at"],
                    snapshot["watermark_updated_at"],
                    _to_int(snapshot["watermark_id"], 0),
                ),
            )
            if pending_row:
                snapshot["source_pending_since_watermark"] = _to_int(
                    pending_row.get("pending_since_watermark"),
                    0,
                )
    except Exception as exc:  # noqa: BLE001
        snapshot["error"] = str(exc)
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)

    return snapshot


@st.cache_data(ttl=5)
def get_dim_cliente_recent_source(limit: int = 20) -> pd.DataFrame:
    config = ETLConfig.from_env()
    connection = None
    try:
        connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        rows = query_all(
            connection,
            """
            SELECT TOP (?)
                customer_id,
                full_name,
                email,
                state,
                updated_at,
                deleted_at
            FROM core.customers
            ORDER BY updated_at DESC, customer_id DESC;
            """,
            (int(limit),),
        )
        return _to_dataframe(rows)
    finally:
        close_quietly(connection)


@st.cache_data(ttl=5)
def get_dim_produto_health() -> dict[str, Any]:
    config = ETLConfig.from_env()
    snapshot: dict[str, Any] = {
        "source_total": 0,
        "source_soft_deleted": 0,
        "source_pending_since_watermark": 0,
        "source_max_updated_at": None,
        "target_total": 0,
        "target_active": 0,
        "target_discontinued": 0,
        "target_invalid_status": 0,
        "target_invalid_price": 0,
        "target_max_updated_at": None,
        "watermark_updated_at": None,
        "watermark_id": 0,
        "last_run_id": None,
        "last_status": None,
        "last_success_at": None,
        "last_entity_status": None,
        "last_entity_finished_at": None,
        "error": None,
    }

    dw_connection = None
    oltp_connection = None
    try:
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        target_row = query_one(
            dw_connection,
            """
            SELECT
                COUNT(*) AS target_total,
                SUM(CASE WHEN situacao = 'Ativo' THEN 1 ELSE 0 END) AS target_active,
                SUM(CASE WHEN situacao = 'Descontinuado' THEN 1 ELSE 0 END) AS target_discontinued,
                SUM(CASE WHEN situacao NOT IN ('Ativo','Inativo','Descontinuado') THEN 1 ELSE 0 END) AS target_invalid_status,
                SUM(CASE WHEN preco_custo < 0 OR preco_sugerido < 0 THEN 1 ELSE 0 END) AS target_invalid_price,
                MAX(data_ultima_atualizacao) AS target_max_updated_at
            FROM dim.DIM_PRODUTO;
            """,
        )
        if target_row:
            snapshot["target_total"] = _to_int(target_row.get("target_total"), 0)
            snapshot["target_active"] = _to_int(target_row.get("target_active"), 0)
            snapshot["target_discontinued"] = _to_int(target_row.get("target_discontinued"), 0)
            snapshot["target_invalid_status"] = _to_int(target_row.get("target_invalid_status"), 0)
            snapshot["target_invalid_price"] = _to_int(target_row.get("target_invalid_price"), 0)
            snapshot["target_max_updated_at"] = target_row.get("target_max_updated_at")

        control_row = query_one(
            dw_connection,
            """
            SELECT
                watermark_updated_at,
                watermark_id,
                last_run_id,
                last_status,
                last_success_at
            FROM ctl.etl_control
            WHERE entity_name = 'dim_produto';
            """,
        )
        if control_row:
            snapshot["watermark_updated_at"] = control_row.get("watermark_updated_at")
            snapshot["watermark_id"] = _to_int(control_row.get("watermark_id"), 0)
            snapshot["last_run_id"] = control_row.get("last_run_id")
            snapshot["last_status"] = control_row.get("last_status")
            snapshot["last_success_at"] = control_row.get("last_success_at")

        entity_row = query_one(
            dw_connection,
            """
            SELECT TOP (1)
                status AS last_entity_status,
                entity_finished_at AS last_entity_finished_at
            FROM audit.etl_run_entity
            WHERE entity_name = 'dim_produto'
            ORDER BY run_entity_id DESC;
            """,
        )
        if entity_row:
            snapshot["last_entity_status"] = entity_row.get("last_entity_status")
            snapshot["last_entity_finished_at"] = entity_row.get("last_entity_finished_at")

        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        source_row = query_one(
            oltp_connection,
            """
            SELECT
                COUNT(*) AS source_total,
                SUM(CASE WHEN deleted_at IS NOT NULL THEN 1 ELSE 0 END) AS source_soft_deleted,
                MAX(updated_at) AS source_max_updated_at
            FROM core.products;
            """,
        )
        if source_row:
            snapshot["source_total"] = _to_int(source_row.get("source_total"), 0)
            snapshot["source_soft_deleted"] = _to_int(source_row.get("source_soft_deleted"), 0)
            snapshot["source_max_updated_at"] = source_row.get("source_max_updated_at")

        if snapshot["watermark_updated_at"] is not None:
            pending_row = query_one(
                oltp_connection,
                """
                SELECT
                    COUNT(*) AS pending_since_watermark
                FROM core.products
                WHERE updated_at > ?
                   OR (updated_at = ? AND product_id > ?);
                """,
                (
                    snapshot["watermark_updated_at"],
                    snapshot["watermark_updated_at"],
                    _to_int(snapshot["watermark_id"], 0),
                ),
            )
            if pending_row:
                snapshot["source_pending_since_watermark"] = _to_int(
                    pending_row.get("pending_since_watermark"),
                    0,
                )
    except Exception as exc:  # noqa: BLE001
        snapshot["error"] = str(exc)
    finally:
        close_quietly(dw_connection)
        close_quietly(oltp_connection)

    return snapshot


@st.cache_data(ttl=5)
def get_dim_produto_recent_source(limit: int = 20) -> pd.DataFrame:
    config = ETLConfig.from_env()
    connection = None
    try:
        connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        rows = query_all(
            connection,
            """
            SELECT TOP (?)
                product_id,
                product_name,
                brand,
                category_name,
                product_status,
                updated_at,
                deleted_at
            FROM core.products
            ORDER BY updated_at DESC, product_id DESC;
            """,
            (int(limit),),
        )
        return _to_dataframe(rows)
    finally:
        close_quietly(connection)


@st.cache_data(ttl=5)
def get_connection_audit_recent(limit: int = 200) -> pd.DataFrame:
    query = """
    SELECT TOP (?)
        connection_event_id,
        event_time_utc,
        login_name,
        host_name,
        program_name,
        database_name,
        status,
        client_net_address,
        encrypt_option,
        auth_scheme
    FROM audit.connection_login_events
    ORDER BY connection_event_id DESC;
    """
    return _fetch_df(query, (int(limit),))


@st.cache_data(ttl=5)
def get_connection_audit_logins(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        ISNULL(login_name, '(null)') AS login_name,
        COUNT(*) AS total_events,
        MAX(event_time_utc) AS last_event_utc
    FROM audit.connection_login_events
    WHERE event_time_utc >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY login_name
    ORDER BY total_events DESC, login_name ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_connection_audit_hourly(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        DATEADD(HOUR, DATEDIFF(HOUR, 0, event_time_utc), 0) AS event_hour_utc,
        COUNT(*) AS total_events
    FROM audit.connection_login_events
    WHERE event_time_utc >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY DATEADD(HOUR, DATEDIFF(HOUR, 0, event_time_utc), 0)
    ORDER BY event_hour_utc ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_connection_audit_programs(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        ISNULL(program_name, '(null)') AS program_name,
        ISNULL(login_name, '(null)') AS login_name,
        COUNT(*) AS total_events,
        MAX(event_time_utc) AS last_event_utc
    FROM audit.connection_login_events
    WHERE event_time_utc >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY program_name, login_name
    ORDER BY total_events DESC, program_name ASC, login_name ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_connection_audit_databases(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        ISNULL(database_name, '(null)') AS database_name,
        COUNT(*) AS total_events,
        MAX(event_time_utc) AS last_event_utc
    FROM audit.connection_login_events
    WHERE event_time_utc >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY database_name
    ORDER BY total_events DESC, database_name ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_connection_audit_statuses(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        ISNULL(status, '(null)') AS status,
        COUNT(*) AS total_events
    FROM audit.connection_login_events
    WHERE event_time_utc >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY status
    ORDER BY total_events DESC, status ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_etl_failures_hourly(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        DATEADD(HOUR, DATEDIFF(HOUR, 0, entity_started_at), 0) AS event_hour_utc,
        COUNT(*) AS failed_entities
    FROM audit.etl_run_entity
    WHERE status = 'failed'
      AND entity_started_at >= DATEADD(HOUR, -?, SYSUTCDATETIME())
    GROUP BY DATEADD(HOUR, DATEDIFF(HOUR, 0, entity_started_at), 0)
    ORDER BY event_hour_utc ASC;
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_etl_failure_summary(hours: int = 24) -> pd.DataFrame:
    query = """
    SELECT
        COUNT(*) AS total_failed_entities,
        COUNT(DISTINCT entity_name) AS failed_entities_distinct,
        COUNT(DISTINCT run_id) AS failed_runs_distinct,
        MAX(entity_started_at) AS last_failed_at
    FROM audit.etl_run_entity
    WHERE status = 'failed'
      AND entity_started_at >= DATEADD(HOUR, -?, SYSUTCDATETIME());
    """
    return _fetch_df(query, (int(hours),))


@st.cache_data(ttl=5)
def get_etl_error_taxonomy(days: int = 14) -> pd.DataFrame:
    query = """
    SELECT
        run_entity_id,
        entity_name,
        error_message
    FROM audit.etl_run_entity
    WHERE status = 'failed'
      AND entity_started_at >= DATEADD(DAY, -?, SYSUTCDATETIME());
    """
    failures_df = _fetch_df(query, (int(days),))
    if failures_df.empty:
        return failures_df

    failures_df = _enrich_failure_dataframe(failures_df)
    grouped = (
        failures_df.groupby(["error_category", "error_reason", "suggested_action"], dropna=False)
        .agg(
            total_errors=("run_entity_id", "count"),
            entities_affected=("entity_name", "nunique"),
            sample_error=("error_signature", "first"),
        )
        .reset_index()
        .sort_values(["total_errors", "error_category"], ascending=[False, True])
    )
    return grouped


@st.cache_data(ttl=5)
def get_etl_failures_recent(limit: int = 120, days: int = 14) -> pd.DataFrame:
    query = """
    SELECT TOP (?)
        run_entity_id,
        run_id,
        entity_name,
        entity_started_at,
        entity_finished_at,
        status,
        extracted_count,
        upserted_count,
        soft_deleted_count,
        error_message
    FROM audit.etl_run_entity
    WHERE status = 'failed'
      AND entity_started_at >= DATEADD(DAY, -?, SYSUTCDATETIME())
    ORDER BY run_entity_id DESC;
    """
    failures_df = _fetch_df(query, (int(limit), int(days)))
    return _enrich_failure_dataframe(failures_df)


def _ensure_datetime_columns(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    if df.empty:
        return df
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def _safe_ratio(numerator: int, denominator: int) -> float | None:
    if denominator <= 0:
        return None
    return (numerator / denominator) * 100.0


def _format_ratio(value: float | None) -> str:
    if value is None:
        return "-"
    return f"{value:.1f}%"


def _compute_freshness_minutes(source_updated_at: Any, target_updated_at: Any) -> float | None:
    if source_updated_at is None or target_updated_at is None:
        return None
    try:
        delta_minutes = (source_updated_at - target_updated_at).total_seconds() / 60.0
    except Exception:  # noqa: BLE001
        return None
    return max(0.0, float(delta_minutes))


def _format_minutes(value: float | None) -> str:
    if value is None:
        return "-"
    if value >= 1440:
        return f"{value / 1440:.1f}d"
    if value >= 60:
        return f"{value / 60:.1f}h"
    return f"{value:.0f}m"


def _render_kpi_cards(runs_df: pd.DataFrame, control_df: pd.DataFrame, entity_runs_df: pd.DataFrame) -> None:
    st.subheader("KPIs OLTP -> DW (escopo monitorado)")

    latest_run = runs_df.iloc[0] if not runs_df.empty else None
    active_entities = int((control_df["is_active"] == 1).sum()) if "is_active" in control_df.columns else 0

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    last_24h_cutoff = now_utc - timedelta(hours=24)
    runs_last_24h = (
        runs_df[runs_df["started_at"] >= last_24h_cutoff]
        if (not runs_df.empty and "started_at" in runs_df.columns)
        else pd.DataFrame()
    )
    total_runs_last_24h = len(runs_last_24h)
    success_runs_last_24h = (
        int((runs_last_24h["status"] == "success").sum()) if not runs_last_24h.empty else 0
    )
    failed_last_24h = (
        int((runs_last_24h["status"] == "failed").sum()) if not runs_last_24h.empty else 0
    )
    success_rate_last_24h = _safe_ratio(success_runs_last_24h, total_runs_last_24h)

    metric_1, metric_2, metric_3, metric_4 = st.columns(4)
    metric_1.metric("Entidades ativas", active_entities)
    metric_2.metric("Taxa de sucesso (24h)", _format_ratio(success_rate_last_24h))
    metric_3.metric("Falhas de run (24h)", failed_last_24h)
    if latest_run is not None:
        metric_4.metric("Status ultimo run", str(latest_run["status"]))
    else:
        metric_4.metric("Status ultimo run", "-")

    overview_df = _ensure_datetime_columns(
        get_pipeline_overview(),
        ["source_max_updated_at", "target_max_updated_at"],
    )
    source_total_all = int(overview_df["source_total"].fillna(0).sum()) if not overview_df.empty else 0
    target_total_all = int(overview_df["target_total"].fillna(0).sum()) if not overview_df.empty else 0
    coverage_global = _safe_ratio(target_total_all, source_total_all)
    pending_total = int(overview_df["source_pending_since_watermark"].fillna(0).sum()) if not overview_df.empty else 0
    freshness_mean = (
        None
        if overview_df.empty or overview_df["freshness_minutes"].dropna().empty
        else float(overview_df["freshness_minutes"].dropna().mean())
    )
    ok_pipelines = int((overview_df["pipeline_status"] == "OK").sum()) if not overview_df.empty else 0
    fail_pipelines = int((overview_df["pipeline_status"] == "FALHA").sum()) if not overview_df.empty else 0
    running_pipelines = int((overview_df["pipeline_status"] == "RODANDO").sum()) if not overview_df.empty else 0
    pending_struct_pipelines = (
        int((overview_df["pipeline_status"] == "PENDENTE_ESTRUTURA").sum()) if not overview_df.empty else 0
    )

    throughput_rows_per_sec = None
    if not entity_runs_df.empty:
        success_entities = entity_runs_df[
            (entity_runs_df["status"] == "success")
            & (entity_runs_df["entity_started_at"] >= last_24h_cutoff)
            & entity_runs_df["entity_started_at"].notna()
            & entity_runs_df["entity_finished_at"].notna()
        ].copy()
        if not success_entities.empty:
            duration_seconds = (
                success_entities["entity_finished_at"] - success_entities["entity_started_at"]
            ).dt.total_seconds()
            success_entities["duration_seconds"] = duration_seconds.clip(lower=1.0)
            success_entities["upserted_count"] = pd.to_numeric(
                success_entities["upserted_count"],
                errors="coerce",
            ).fillna(0)
            throughput_series = success_entities["upserted_count"] / success_entities["duration_seconds"]
            throughput_rows_per_sec = float(throughput_series.mean()) if not throughput_series.empty else None

    metric_5, metric_6, metric_7, metric_8 = st.columns(4)
    metric_5.metric("Cobertura geral", _format_ratio(coverage_global))
    metric_6.metric("Pendentes watermark", pending_total)
    metric_7.metric("Latencia media", _format_minutes(freshness_mean))
    metric_8.metric("Throughput medio (24h)", "-" if throughput_rows_per_sec is None else f"{throughput_rows_per_sec:.1f} l/s")

    metric_9, metric_10, metric_11, metric_12 = st.columns(4)
    metric_9.metric("Pipelines OK", ok_pipelines)
    metric_10.metric("Pipelines em falha", fail_pipelines)
    metric_11.metric("Pipelines rodando", running_pipelines)
    metric_12.metric("Pendentes estrutura", pending_struct_pipelines)

    st.caption(
        "KPIs principais: sucesso dos runs, cobertura global, pendencia incremental, "
        "latencia media e status operacional dos pipelines."
    )


def _render_pipeline_overview_section() -> None:
    st.subheader("Contexto geral dos pipelines")
    overview_df = _ensure_datetime_columns(
        get_pipeline_overview(),
        [
            "watermark_updated_at",
            "last_success_at",
            "entity_last_started_at",
            "entity_last_finished_at",
            "source_max_updated_at",
            "target_max_updated_at",
        ],
    )
    if overview_df.empty:
        st.info("Sem entidades cadastradas no controle ETL.")
        return

    total = len(overview_df)
    ok_count = int((overview_df["pipeline_status"] == "OK").sum())
    fail_count = int((overview_df["pipeline_status"] == "FALHA").sum())
    running_count = int((overview_df["pipeline_status"] == "RODANDO").sum())
    pending_struct_count = int((overview_df["pipeline_status"] == "PENDENTE_ESTRUTURA").sum())
    no_exec_count = int((overview_df["pipeline_status"] == "SEM_EXECUCAO").sum())

    k1, k2, k3, k4, k5, k6 = st.columns(6)
    k1.metric("Pipelines", total)
    k2.metric("OK", ok_count)
    k3.metric("Falha", fail_count)
    k4.metric("Rodando", running_count)
    k5.metric("Pendente estrutura", pending_struct_count)
    k6.metric("Sem execucao", no_exec_count)

    m1, m2, m3 = st.columns(3)
    m1.metric("Pendencia total", int(overview_df["source_pending_since_watermark"].fillna(0).sum()))
    m2.metric(
        "Latencia media",
        _format_minutes(
            None
            if overview_df["freshness_minutes"].dropna().empty
            else float(overview_df["freshness_minutes"].dropna().mean())
        ),
    )
    m3.metric(
        "Throughput medio",
        "-"
        if overview_df["entity_last_throughput_rows_per_sec"].dropna().empty
        else f"{float(overview_df['entity_last_throughput_rows_per_sec'].dropna().mean()):.1f} l/s",
    )

    status_options = sorted(overview_df["pipeline_status"].astype(str).unique().tolist())
    selected_status = st.multiselect(
        "Filtrar status do pipeline",
        options=status_options,
        default=status_options,
    )
    filtered_df = overview_df[overview_df["pipeline_status"].isin(selected_status)].copy()
    filtered_df["is_active"] = filtered_df["is_active"].apply(lambda x: "SIM" if _to_bool(x) else "NAO")
    filtered_df["source_exists"] = filtered_df["source_exists"].apply(lambda x: "OK" if bool(x) else "PENDENTE")
    filtered_df["target_exists"] = filtered_df["target_exists"].apply(lambda x: "OK" if bool(x) else "PENDENTE")
    filtered_df["coverage_percent"] = filtered_df["coverage_percent"].apply(_format_ratio)
    filtered_df["freshness_minutes"] = filtered_df["freshness_minutes"].apply(_format_minutes)
    filtered_df["entity_last_duration_seconds"] = filtered_df["entity_last_duration_seconds"].apply(
        lambda x: _format_minutes(None if pd.isna(x) else float(x) / 60.0),
    )
    filtered_df["entity_last_throughput_rows_per_sec"] = filtered_df["entity_last_throughput_rows_per_sec"].apply(
        lambda x: "-" if pd.isna(x) else f"{float(x):.1f}",
    )
    filtered_df["entity_last_error"] = filtered_df["entity_last_error"].fillna("")

    display_columns = [
        "entity_name",
        "pipeline_status",
        "is_active",
        "source_exists",
        "target_exists",
        "source_total",
        "target_total",
        "coverage_percent",
        "source_pending_since_watermark",
        "freshness_minutes",
        "control_last_status",
        "entity_last_status",
        "entity_last_extracted",
        "entity_last_upserted",
        "entity_last_soft_deleted",
        "entity_last_duration_seconds",
        "entity_last_throughput_rows_per_sec",
        "entity_last_finished_at",
        "watermark_updated_at",
        "watermark_id",
        "entity_last_error",
    ]
    st.dataframe(
        filtered_df[display_columns],
        use_container_width=True,
        hide_index=True,
    )

    st.caption(
        "Matriz geral de acompanhamento: status, cobertura, pendencia incremental, "
        "latencia, duracao e throughput por pipeline. "
        "Use `pipeline_status` para auditoria rapida: "
        "`OK` (saudavel), `FALHA` (ultima execucao com erro), "
        "`RODANDO` (run em andamento), `PENDENTE_ESTRUTURA` (fonte/alvo ausente), "
        "`SEM_EXECUCAO` (ainda sem historico)."
    )


def _render_pipeline_health_section(control_df: pd.DataFrame) -> None:
    st.subheader("Saude por pipeline")
    if control_df.empty or "entity_name" not in control_df.columns:
        st.info("Sem entidades cadastradas no controle ETL.")
        return

    entity_options = control_df["entity_name"].astype(str).sort_values().unique().tolist()
    selected_entity = st.selectbox(
        "Selecionar entidade/fato",
        options=entity_options,
        index=0,
    )

    health = get_pipeline_health(selected_entity)
    if health.get("error"):
        st.warning("Nao foi possivel calcular a saude do pipeline selecionado.")
        st.code(str(health["error"]))
        return

    source_total = _to_int(health.get("source_total"), 0)
    target_total = _to_int(health.get("target_total"), 0)
    pending_total = _to_int(health.get("source_pending_since_watermark"), 0)
    delta_rows = target_total - source_total

    metric_1, metric_2, metric_3, metric_4 = st.columns(4)
    metric_1.metric("Fonte", source_total)
    metric_2.metric("Alvo", target_total, delta=delta_rows)
    metric_3.metric("Pendentes no watermark", pending_total)
    metric_4.metric("Cobertura", _format_ratio(health.get("coverage_percent")))

    metric_5, metric_6, metric_7, metric_8 = st.columns(4)
    metric_5.metric("Ativo no controle", "SIM" if _to_bool(health.get("is_active")) else "NAO")
    metric_6.metric("Status controle", str(health.get("last_status") or "-"))
    metric_7.metric("Status ultima execucao", str(health.get("last_entity_status") or "-"))
    metric_8.metric("Latencia", _format_minutes(health.get("freshness_minutes")))

    metric_9, metric_10 = st.columns(2)
    metric_9.metric(
        "Duracao ultima execucao",
        _format_minutes(None if health.get("last_duration_seconds") is None else float(health["last_duration_seconds"]) / 60.0),
    )
    metric_10.metric(
        "Throughput ultima execucao",
        "-" if health.get("last_throughput_rows_per_sec") is None else f"{float(health['last_throughput_rows_per_sec']):.1f} l/s",
    )

    st.caption(
        f"Pipeline: `{health.get('entity_name')}` | "
        f"Fonte: `{health.get('source_table')}` -> Alvo: `{health.get('target_table')}` | "
        f"Watermark: `{health.get('watermark_updated_at')} / {health.get('watermark_id')}`"
    )

    detail_left, detail_right = st.columns(2)
    with detail_left:
        st.markdown("**Auditoria da ultima execucao**")
        audit_rows = [
            {"campo": "last_run_id", "valor": str(health.get("last_run_id"))},
            {"campo": "last_success_at", "valor": str(health.get("last_success_at"))},
            {"campo": "entity_started_at", "valor": str(health.get("last_entity_started_at"))},
            {"campo": "entity_finished_at", "valor": str(health.get("last_entity_finished_at"))},
            {"campo": "extraidos", "valor": str(_to_int(health.get("last_entity_extracted"), 0))},
            {"campo": "upsertados", "valor": str(_to_int(health.get("last_entity_upserted"), 0))},
            {"campo": "soft_deleted", "valor": str(_to_int(health.get("last_entity_soft_deleted"), 0))},
        ]
        st.dataframe(pd.DataFrame(audit_rows), use_container_width=True, hide_index=True)
    with detail_right:
        st.markdown("**Qualidade e reconciliacao (generico)**")
        quality_snapshot = get_pipeline_quality_snapshot(selected_entity)
        if quality_snapshot.get("error"):
            st.warning("Falha ao calcular checks genericos de qualidade/reconciliacao.")
            st.code(str(quality_snapshot["error"]))
        else:
            q1, q2, q3 = st.columns(3)
            q1.metric("Checks OK", _to_int(quality_snapshot.get("ok_count"), 0))
            q2.metric("Checks atencao", _to_int(quality_snapshot.get("warning_count"), 0))
            q3.metric("Checks alerta", _to_int(quality_snapshot.get("alert_count"), 0))
            checks_df = pd.DataFrame(quality_snapshot.get("checks", []))
            if checks_df.empty:
                st.info("Sem checks disponiveis para este pipeline.")
            else:
                st.dataframe(checks_df, use_container_width=True, hide_index=True)

    last_error = str(health.get("last_entity_error") or "").strip()
    if last_error:
        st.markdown("**Ultimo erro da entidade**")
        st.code(last_error)

    st.markdown("**Registros recentes da origem**")
    source_recent_df = _ensure_datetime_columns(
        get_pipeline_recent_source(selected_entity, 20),
        ["updated_at", "deleted_at", "created_at"],
    )
    if source_recent_df.empty:
        st.info("Nao foi possivel carregar amostra recente da origem para este pipeline.")
    else:
        st.dataframe(source_recent_df, use_container_width=True, hide_index=True)


def _render_dim_cliente_section() -> None:
    st.subheader("Saude da dim_cliente")
    dim_cliente_health = get_dim_cliente_health()
    if dim_cliente_health.get("error"):
        st.warning("Nao foi possivel calcular a saude da dim_cliente.")
        st.code(str(dim_cliente_health["error"]))
        return

    source_total = _to_int(dim_cliente_health.get("source_total"), 0)
    target_total = _to_int(dim_cliente_health.get("target_total"), 0)
    delta_rows = target_total - source_total

    health_col_1, health_col_2, health_col_3, health_col_4 = st.columns(4)
    health_col_1.metric("Fonte core.customers", source_total)
    health_col_2.metric("Alvo dim.DIM_CLIENTE", target_total, delta=delta_rows)
    health_col_3.metric("Pendentes no cutoff", _to_int(dim_cliente_health.get("source_pending_since_watermark"), 0))
    health_col_4.metric("Sem email (DW)", _to_int(dim_cliente_health.get("target_no_email"), 0))

    st.caption(
        "Watermark atual dim_cliente: "
        f"{dim_cliente_health.get('watermark_updated_at')} / {dim_cliente_health.get('watermark_id')}"
    )

    quality_left, quality_right = st.columns(2)
    with quality_left:
        st.markdown("**Qualidade no alvo (dim.DIM_CLIENTE)**")
        quality_rows = [
            {"check": "clientes ativos", "valor": _to_int(dim_cliente_health.get("target_active"), 0)},
            {"check": "clientes vip", "valor": _to_int(dim_cliente_health.get("target_vip"), 0)},
            {"check": "soft delete na fonte", "valor": _to_int(dim_cliente_health.get("source_soft_deleted"), 0)},
            {"check": "estado invalido", "valor": _to_int(dim_cliente_health.get("target_invalid_state"), 0)},
            {"check": "ultima atualizacao alvo", "valor": str(dim_cliente_health.get("target_max_updated_at"))},
            {"check": "ultima atualizacao fonte", "valor": str(dim_cliente_health.get("source_max_updated_at"))},
            {"check": "ultimo status controle", "valor": str(dim_cliente_health.get("last_status"))},
            {"check": "ultimo status entidade", "valor": str(dim_cliente_health.get("last_entity_status"))},
        ]
        quality_df = pd.DataFrame(quality_rows)
        quality_df["valor"] = quality_df["valor"].astype(str)
        st.dataframe(quality_df, use_container_width=True, hide_index=True)
    with quality_right:
        st.markdown("**Registros mais recentes na origem (core.customers)**")
        try:
            source_recent_df = _ensure_datetime_columns(
                get_dim_cliente_recent_source(20),
                ["updated_at", "deleted_at"],
            )
            st.dataframe(source_recent_df, use_container_width=True, hide_index=True)
        except Exception as exc:  # noqa: BLE001
            st.warning("Nao foi possivel consultar os registros recentes da origem.")
            st.code(str(exc))


def _render_dim_produto_section() -> None:
    st.subheader("Saude da dim_produto")
    dim_produto_health = get_dim_produto_health()
    if dim_produto_health.get("error"):
        st.warning("Nao foi possivel calcular a saude da dim_produto.")
        st.code(str(dim_produto_health["error"]))
        return

    source_total = _to_int(dim_produto_health.get("source_total"), 0)
    target_total = _to_int(dim_produto_health.get("target_total"), 0)
    delta_rows = target_total - source_total

    health_col_1, health_col_2, health_col_3, health_col_4 = st.columns(4)
    health_col_1.metric("Fonte core.products", source_total)
    health_col_2.metric("Alvo dim.DIM_PRODUTO", target_total, delta=delta_rows)
    health_col_3.metric("Pendentes no cutoff", _to_int(dim_produto_health.get("source_pending_since_watermark"), 0))
    health_col_4.metric("Descontinuados (DW)", _to_int(dim_produto_health.get("target_discontinued"), 0))

    st.caption(
        "Watermark atual dim_produto: "
        f"{dim_produto_health.get('watermark_updated_at')} / {dim_produto_health.get('watermark_id')}"
    )

    quality_left, quality_right = st.columns(2)
    with quality_left:
        st.markdown("**Qualidade no alvo (dim.DIM_PRODUTO)**")
        quality_rows = [
            {"check": "produtos ativos", "valor": _to_int(dim_produto_health.get("target_active"), 0)},
            {"check": "soft delete na fonte", "valor": _to_int(dim_produto_health.get("source_soft_deleted"), 0)},
            {"check": "status invalido", "valor": _to_int(dim_produto_health.get("target_invalid_status"), 0)},
            {"check": "preco invalido", "valor": _to_int(dim_produto_health.get("target_invalid_price"), 0)},
            {"check": "ultima atualizacao alvo", "valor": str(dim_produto_health.get("target_max_updated_at"))},
            {"check": "ultima atualizacao fonte", "valor": str(dim_produto_health.get("source_max_updated_at"))},
            {"check": "ultimo status controle", "valor": str(dim_produto_health.get("last_status"))},
            {"check": "ultimo status entidade", "valor": str(dim_produto_health.get("last_entity_status"))},
        ]
        quality_df = pd.DataFrame(quality_rows)
        quality_df["valor"] = quality_df["valor"].astype(str)
        st.dataframe(quality_df, use_container_width=True, hide_index=True)
    with quality_right:
        st.markdown("**Registros mais recentes na origem (core.products)**")
        try:
            source_recent_df = _ensure_datetime_columns(
                get_dim_produto_recent_source(20),
                ["updated_at", "deleted_at"],
            )
            st.dataframe(source_recent_df, use_container_width=True, hide_index=True)
        except Exception as exc:  # noqa: BLE001
            st.warning("Nao foi possivel consultar os registros recentes da origem.")
            st.code(str(exc))


def _render_running_section() -> None:
    running_runs_df = _ensure_datetime_columns(get_running_runs(), ["started_at"])
    running_entities_df = _ensure_datetime_columns(get_running_entities(), ["entity_started_at"])

    st.subheader("Execucao em andamento agora")
    if running_runs_df.empty and running_entities_df.empty:
        st.info("Nenhum run em andamento no momento.")
        return

    running_col_1, running_col_2 = st.columns(2)
    with running_col_1:
        st.markdown("**Runs com status `running`**")
        st.dataframe(running_runs_df, use_container_width=True, hide_index=True)
    with running_col_2:
        st.markdown("**Entidades com status `running`**")
        st.dataframe(running_entities_df, use_container_width=True, hide_index=True)


def _render_execution_timeline_section() -> None:
    st.subheader("Timeline de execucao por run e entidade")
    timeline_df = _ensure_datetime_columns(
        get_execution_timeline(400),
        ["run_started_at", "entity_started_at", "entity_finished_at"],
    )
    if timeline_df.empty:
        st.info("Sem historico de execucao para montar timeline.")
        return

    run_options = sorted(timeline_df["run_id"].dropna().astype(int).unique().tolist(), reverse=True)
    default_runs = run_options[: min(10, len(run_options))]
    selected_runs = st.multiselect(
        "Filtrar run_id na timeline",
        options=run_options,
        default=default_runs,
    )
    filtered_df = timeline_df[timeline_df["run_id"].astype(int).isin(selected_runs)].copy()
    if filtered_df.empty:
        st.info("Nenhum dado para os runs selecionados.")
        return

    filtered_df = filtered_df[filtered_df["entity_started_at"].notna()].copy()
    if filtered_df.empty:
        st.info("Runs selecionados sem inicio de entidade registrado.")
        return

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    filtered_df["timeline_finished_at"] = filtered_df["entity_finished_at"].fillna(now_utc)
    filtered_df["duration_seconds"] = (
        filtered_df["timeline_finished_at"] - filtered_df["entity_started_at"]
    ).dt.total_seconds().clip(lower=0)
    filtered_df["duration_seconds"] = filtered_df["duration_seconds"].fillna(0)
    filtered_df["execution_key"] = filtered_df.apply(
        lambda row: f"run {int(row['run_id'])} | {row['entity_name']}",
        axis=1,
    )
    filtered_df["status"] = filtered_df["status"].fillna("unknown").astype(str)

    run_count = int(filtered_df["run_id"].nunique())
    entity_count = int(filtered_df["entity_name"].nunique())
    running_count = int((filtered_df["status"] == "running").sum())
    failed_count = int((filtered_df["status"] == "failed").sum())
    metric_1, metric_2, metric_3, metric_4 = st.columns(4)
    metric_1.metric("Runs selecionados", run_count)
    metric_2.metric("Entidades na timeline", entity_count)
    metric_3.metric("Execucoes rodando", running_count)
    metric_4.metric("Execucoes com falha", failed_count)

    chart_height = min(900, max(260, 20 * len(filtered_df)))
    status_scale = alt.Scale(
        domain=["success", "running", "failed", "partial", "unknown"],
        range=["#00A86B", "#1E90FF", "#DC143C", "#FF8C00", "#708090"],
    )
    chart = (
        alt.Chart(filtered_df)
        .mark_bar()
        .encode(
            x=alt.X("entity_started_at:T", title="Inicio"),
            x2=alt.X2("timeline_finished_at:T"),
            y=alt.Y("execution_key:N", title="Run / Entidade", sort="-x"),
            color=alt.Color("status:N", title="Status", scale=status_scale),
            tooltip=[
                alt.Tooltip("run_id:Q", title="run_id"),
                alt.Tooltip("entity_name:N", title="entidade"),
                alt.Tooltip("status:N", title="status"),
                alt.Tooltip("entity_started_at:T", title="inicio"),
                alt.Tooltip("entity_finished_at:T", title="fim"),
                alt.Tooltip("duration_seconds:Q", title="duracao (s)", format=".0f"),
                alt.Tooltip("extracted_count:Q", title="extraidos"),
                alt.Tooltip("upserted_count:Q", title="upsertados"),
                alt.Tooltip("soft_deleted_count:Q", title="soft_deleted"),
            ],
        )
        .properties(height=chart_height)
    )
    st.altair_chart(chart, use_container_width=True)

    detail_columns = [
        "run_id",
        "entity_name",
        "status",
        "entity_started_at",
        "entity_finished_at",
        "duration_seconds",
        "extracted_count",
        "upserted_count",
        "soft_deleted_count",
        "error_message",
    ]
    st.dataframe(
        filtered_df[detail_columns].sort_values(["run_id", "entity_started_at"], ascending=[False, False]),
        use_container_width=True,
        hide_index=True,
    )


def _render_alerts_sla_section(runs_df: pd.DataFrame, entity_runs_df: pd.DataFrame) -> None:
    st.subheader("Alertas e SLA dos pipelines")
    overview_df = _ensure_datetime_columns(
        get_pipeline_overview(),
        ["last_success_at", "entity_last_started_at", "entity_last_finished_at"],
    )
    if overview_df.empty:
        st.info("Sem pipelines para avaliar SLA.")
        return

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff_24h = now_utc - timedelta(hours=24)
    cutoff_7d = now_utc - timedelta(days=7)

    runs_24h = (
        runs_df[runs_df["started_at"] >= cutoff_24h]
        if (not runs_df.empty and "started_at" in runs_df.columns)
        else pd.DataFrame()
    )
    runs_7d = (
        runs_df[runs_df["started_at"] >= cutoff_7d]
        if (not runs_df.empty and "started_at" in runs_df.columns)
        else pd.DataFrame()
    )

    success_rate_24h = _safe_ratio(
        int((runs_24h["status"] == "success").sum()) if not runs_24h.empty else 0,
        len(runs_24h),
    )
    success_rate_7d = _safe_ratio(
        int((runs_7d["status"] == "success").sum()) if not runs_7d.empty else 0,
        len(runs_7d),
    )

    active_df = overview_df[overview_df["is_active"].apply(_to_bool)].copy()
    alert_rows: list[dict[str, Any]] = []

    if not entity_runs_df.empty and "entity_started_at" in entity_runs_df.columns:
        entity_runs_7d = entity_runs_df[entity_runs_df["entity_started_at"] >= cutoff_7d].copy()
    else:
        entity_runs_7d = pd.DataFrame()

    for _, row in active_df.iterrows():
        entity_name = str(row.get("entity_name") or "")
        freshness = row.get("freshness_minutes")
        if freshness is not None and not pd.isna(freshness):
            freshness_value = float(freshness)
            if freshness_value > 120:
                severity = "ALERTA" if freshness_value > 360 else "ATENCAO"
                alert_rows.append(
                    {
                        "severidade": severity,
                        "tipo": "ATRASO_WATERMARK",
                        "entidade": entity_name,
                        "valor": _format_minutes(freshness_value),
                        "detalhe": "Latencia acima do limite (120 minutos).",
                    }
                )

        last_finished = row.get("entity_last_finished_at")
        if pd.isna(last_finished) or last_finished is None:
            alert_rows.append(
                {
                    "severidade": "ALERTA",
                    "tipo": "SEM_EXECUCAO_RECENTE",
                    "entidade": entity_name,
                    "valor": "-",
                    "detalhe": "Pipeline ativo sem historico de execucao da entidade.",
                }
            )
        else:
            idle_hours = (now_utc - last_finished).total_seconds() / 3600.0
            if idle_hours > 24:
                severity = "ALERTA" if idle_hours > 72 else "ATENCAO"
                alert_rows.append(
                    {
                        "severidade": severity,
                        "tipo": "SEM_EXECUCAO_RECENTE",
                        "entidade": entity_name,
                        "valor": f"{idle_hours:.1f}h",
                        "detalhe": "Ultima execucao acima do limite (24 horas).",
                    }
                )

        if not entity_runs_7d.empty:
            entity_scope = entity_runs_7d[entity_runs_7d["entity_name"] == entity_name]
            total_entity_runs = len(entity_scope)
            failed_entity_runs = int((entity_scope["status"] == "failed").sum()) if total_entity_runs > 0 else 0
            fail_rate = _safe_ratio(failed_entity_runs, total_entity_runs)
            if total_entity_runs >= 3 and (fail_rate or 0) >= 30.0:
                severity = "ALERTA" if (fail_rate or 0) >= 50.0 else "ATENCAO"
                alert_rows.append(
                    {
                        "severidade": severity,
                        "tipo": "FALHA_RECORRENTE",
                        "entidade": entity_name,
                        "valor": _format_ratio(fail_rate),
                        "detalhe": f"Falha recorrente na janela de 7 dias ({failed_entity_runs}/{total_entity_runs}).",
                    }
                )

    alerts_df = pd.DataFrame(alert_rows)
    total_active = len(active_df)
    entities_with_alert = int(alerts_df["entidade"].nunique()) if not alerts_df.empty else 0
    sla_compliance = _safe_ratio(total_active - entities_with_alert, total_active)

    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Taxa sucesso (24h)", _format_ratio(success_rate_24h))
    k2.metric("Taxa sucesso (7d)", _format_ratio(success_rate_7d))
    k3.metric("Conformidade SLA", _format_ratio(sla_compliance))
    k4.metric("Alertas abertos", len(alerts_df))

    if alerts_df.empty:
        st.success("Sem alertas ativos para os pipelines monitorados.")
    else:
        severity_order = {"ALERTA": 0, "ATENCAO": 1}
        alerts_df["order"] = alerts_df["severidade"].map(severity_order).fillna(9)
        alerts_df = alerts_df.sort_values(["order", "tipo", "entidade"]).drop(columns=["order"])
        st.dataframe(alerts_df, use_container_width=True, hide_index=True)

    st.caption(
        "Regras de alerta: atraso de watermark > 120m, pipeline sem execucao > 24h, "
        "falha recorrente >= 30% na janela de 7 dias (com minimo de 3 execucoes)."
    )


def _render_runs_control_section(runs_df: pd.DataFrame, control_df: pd.DataFrame) -> None:
    st.subheader("Controle incremental (ctl.etl_control)")
    st.dataframe(control_df, use_container_width=True, hide_index=True)

    st.subheader("Ultimos runs (audit.etl_run)")
    st.dataframe(runs_df, use_container_width=True, hide_index=True)

    if runs_df.empty:
        return

    run_ids = runs_df["run_id"].astype(int).tolist()
    selected_run_id = st.selectbox("Detalhar run", options=run_ids, index=0)
    run_detail_df = _ensure_datetime_columns(
        get_run_entity_details(selected_run_id),
        [
            "entity_started_at",
            "entity_finished_at",
            "watermark_from_updated_at",
            "watermark_to_updated_at",
        ],
    )
    st.subheader(f"Detalhe por entidade - run_id {selected_run_id}")
    st.dataframe(run_detail_df, use_container_width=True, hide_index=True)


def _render_charts_section() -> None:
    chart_col_1, chart_col_2 = st.columns(2)

    with chart_col_1:
        st.subheader("Runs por status (ultimos 14 dias)")
        daily_df = get_daily_run_summary(14)
        if daily_df.empty:
            st.info("Sem dados de runs para o periodo.")
        else:
            pivot = (
                daily_df.pivot_table(
                    index="run_date",
                    columns="status",
                    values="total_runs",
                    aggfunc="sum",
                    fill_value=0,
                )
                .sort_index()
            )
            st.line_chart(pivot)

    with chart_col_2:
        st.subheader("Volume por entidade (ultimos 14 dias)")
        volume_df = get_entity_volume(14)
        if volume_df.empty:
            st.info("Sem volume de entidades para o periodo.")
        else:
            chart_df = volume_df.set_index("entity_name")[["extracted_total", "upserted_total"]]
            st.bar_chart(chart_df)


def _render_failures_section(entity_runs_df: pd.DataFrame) -> None:
    st.subheader("Falhas recentes por entidade")
    if entity_runs_df.empty:
        st.info("Sem falhas registradas.")
        return

    failures = entity_runs_df[entity_runs_df["status"] == "failed"].copy()
    if failures.empty:
        st.success("Nenhuma falha encontrada no historico carregado.")
        return

    failures = _enrich_failure_dataframe(failures)
    st.dataframe(
        failures[
            [
                "run_id",
                "entity_name",
                "entity_started_at",
                "entity_finished_at",
                "error_category",
                "error_reason",
                "suggested_action",
                "error_signature",
                "error_message",
            ]
        ],
        use_container_width=True,
        hide_index=True,
    )


def _render_connection_audit_section() -> None:
    st.subheader("Auditoria tecnica consolidada")

    c1, c2, c3, c4 = st.columns([1, 1, 1, 1.2])
    with c1:
        hours_window = st.select_slider(
            "Janela (horas)",
            options=[6, 12, 24, 48, 72, 168],
            value=24,
        )
    with c2:
        recent_limit = st.select_slider(
            "Limite eventos",
            options=[100, 150, 300, 500, 1000],
            value=300,
        )
    with c3:
        failure_days = st.select_slider(
            "Janela erros (dias)",
            options=[3, 7, 14, 30],
            value=14,
        )
    with c4:
        if st.button("Capturar snapshot agora"):
            ok, error_text = capture_connection_snapshot_now()
            if ok:
                st.cache_data.clear()
                st.success("Snapshot de conexoes capturado.")
            else:
                st.warning("Falha ao capturar snapshot de conexoes.")
                if error_text:
                    st.code(error_text)

    conn_hourly_df = _ensure_datetime_columns(get_connection_audit_hourly(hours_window), ["event_hour_utc"])
    conn_logins_df = _ensure_datetime_columns(get_connection_audit_logins(hours_window), ["last_event_utc"])
    conn_programs_df = _ensure_datetime_columns(get_connection_audit_programs(hours_window), ["last_event_utc"])
    conn_databases_df = _ensure_datetime_columns(get_connection_audit_databases(hours_window), ["last_event_utc"])
    conn_status_df = get_connection_audit_statuses(hours_window)
    conn_recent_df = _ensure_datetime_columns(
        get_connection_audit_recent(recent_limit),
        ["event_time_utc", "login_time"],
    )
    etl_fail_hourly_df = _ensure_datetime_columns(get_etl_failures_hourly(hours_window), ["event_hour_utc"])
    etl_fail_summary_df = _ensure_datetime_columns(get_etl_failure_summary(hours_window), ["last_failed_at"])
    etl_error_taxonomy_df = get_etl_error_taxonomy(failure_days)
    etl_fail_recent_df = _ensure_datetime_columns(
        get_etl_failures_recent(200, failure_days),
        ["entity_started_at", "entity_finished_at"],
    )

    total_conn_events = int(conn_status_df["total_events"].sum()) if not conn_status_df.empty else 0
    unique_logins = int(conn_recent_df["login_name"].astype(str).nunique()) if not conn_recent_df.empty else 0
    unique_hosts = int(conn_recent_df["host_name"].astype(str).nunique()) if not conn_recent_df.empty else 0
    failed_entities = 0
    last_failed_at = None
    if not etl_fail_summary_df.empty:
        failed_entities = _to_int(etl_fail_summary_df.iloc[0].get("total_failed_entities"), 0)
        last_failed_at = etl_fail_summary_df.iloc[0].get("last_failed_at")

    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Eventos conexao (janela)", total_conn_events)
    m2.metric("Logins unicos", unique_logins)
    m3.metric("Hosts unicos", unique_hosts)
    m4.metric("Falhas ETL (janela)", failed_entities)

    st.caption(f"Ultima falha ETL na janela: `{last_failed_at}`")

    st.markdown("**Correlacao temporal: conexoes x falhas ETL**")
    if conn_hourly_df.empty and etl_fail_hourly_df.empty:
        st.info("Sem eventos para correlacao temporal nesta janela.")
    else:
        chart_df = pd.DataFrame()
        if not conn_hourly_df.empty:
            chart_df = conn_hourly_df.rename(columns={"total_events": "conexoes"}).copy()
        if not etl_fail_hourly_df.empty:
            if chart_df.empty:
                chart_df = etl_fail_hourly_df.rename(columns={"failed_entities": "falhas_etl"}).copy()
            else:
                chart_df = chart_df.merge(
                    etl_fail_hourly_df.rename(columns={"failed_entities": "falhas_etl"}),
                    on="event_hour_utc",
                    how="outer",
                )
        chart_df = chart_df.sort_values("event_hour_utc").fillna(0)
        for col in ["conexoes", "falhas_etl"]:
            if col not in chart_df.columns:
                chart_df[col] = 0
        st.line_chart(chart_df.set_index("event_hour_utc")[["conexoes", "falhas_etl"]])

    st.markdown("**Top visoes tecnicas de conexao**")
    tabs = st.tabs(["Top logins", "Programas", "Bases", "Status"])
    with tabs[0]:
        if conn_logins_df.empty:
            st.info("Sem eventos por login na janela.")
        else:
            st.dataframe(conn_logins_df, use_container_width=True, hide_index=True)
    with tabs[1]:
        if conn_programs_df.empty:
            st.info("Sem eventos por programa na janela.")
        else:
            st.dataframe(conn_programs_df, use_container_width=True, hide_index=True)
    with tabs[2]:
        if conn_databases_df.empty:
            st.info("Sem eventos por base na janela.")
        else:
            st.dataframe(conn_databases_df, use_container_width=True, hide_index=True)
    with tabs[3]:
        if conn_status_df.empty:
            st.info("Sem eventos por status na janela.")
        else:
            st.dataframe(conn_status_df, use_container_width=True, hide_index=True)

    st.markdown("**Falhas ETL por tipo de erro**")
    if etl_error_taxonomy_df.empty:
        st.success("Nenhuma falha ETL registrada na janela de analise.")
    else:
        ordered_cols = [
            "error_category",
            "error_reason",
            "total_errors",
            "entities_affected",
            "suggested_action",
            "sample_error",
        ]
        display_cols = [col for col in ordered_cols if col in etl_error_taxonomy_df.columns]
        st.dataframe(etl_error_taxonomy_df[display_cols], use_container_width=True, hide_index=True)

    st.markdown("**Falhas ETL recentes (filtro tecnico)**")
    if etl_fail_recent_df.empty:
        st.info("Sem falhas ETL recentes para exibir.")
    else:
        category_options = sorted(etl_fail_recent_df["error_category"].astype(str).unique().tolist())
        entity_options = sorted(etl_fail_recent_df["entity_name"].astype(str).unique().tolist())
        col_f1, col_f2 = st.columns(2)
        with col_f1:
            selected_categories = st.multiselect(
                "Filtrar categoria de erro",
                options=category_options,
                default=category_options,
            )
        with col_f2:
            selected_entities = st.multiselect(
                "Filtrar entidade",
                options=entity_options,
                default=entity_options,
            )

        filtered_fail_df = etl_fail_recent_df[
            etl_fail_recent_df["error_category"].astype(str).isin(selected_categories)
            & etl_fail_recent_df["entity_name"].astype(str).isin(selected_entities)
        ].copy()
        st.dataframe(
            filtered_fail_df[
                [
                    "run_id",
                    "entity_name",
                    "entity_started_at",
                    "entity_finished_at",
                    "error_category",
                    "error_reason",
                    "suggested_action",
                    "error_signature",
                    "error_message",
                ]
            ],
            use_container_width=True,
            hide_index=True,
        )

    st.markdown("**Eventos de conexao recentes (filtro tecnico)**")
    if conn_recent_df.empty:
        st.info("Nenhum evento recente de conexao.")
        return

    login_opts = sorted(conn_recent_df["login_name"].astype(str).unique().tolist())
    program_opts = sorted(conn_recent_df["program_name"].astype(str).unique().tolist())
    database_opts = sorted(conn_recent_df["database_name"].astype(str).unique().tolist())
    status_opts = sorted(conn_recent_df["status"].astype(str).unique().tolist())

    flt1, flt2, flt3, flt4 = st.columns(4)
    with flt1:
        selected_logins = st.multiselect("Login", options=login_opts, default=login_opts)
    with flt2:
        selected_programs = st.multiselect("Programa", options=program_opts, default=program_opts)
    with flt3:
        selected_databases = st.multiselect("Database", options=database_opts, default=database_opts)
    with flt4:
        selected_status = st.multiselect("Status conexao", options=status_opts, default=status_opts)

    filtered_conn_df = conn_recent_df[
        conn_recent_df["login_name"].astype(str).isin(selected_logins)
        & conn_recent_df["program_name"].astype(str).isin(selected_programs)
        & conn_recent_df["database_name"].astype(str).isin(selected_databases)
        & conn_recent_df["status"].astype(str).isin(selected_status)
    ].copy()
    st.dataframe(filtered_conn_df, use_container_width=True, hide_index=True)


def render_dashboard() -> None:
    st.title("ETL Monitor - DW E-commerce")
    st.caption("Acompanhamento visual dos runs ETL (audit.* e ctl.etl_control).")

    col_a, col_b, col_c = st.columns([1, 1, 1.5])
    with col_a:
        if st.button("Atualizar agora"):
            st.cache_data.clear()
            st.rerun()
    with col_b:
        auto_refresh = st.toggle("Auto-refresh", value=True)
    with col_c:
        refresh_seconds = st.slider("Intervalo (segundos)", min_value=5, max_value=60, value=10, step=5)

    col_d, col_e = st.columns([1, 1])
    with col_d:
        st.caption(f"Atualizado em UTC: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}")
    with col_e:
        st.caption(f"Auto-refresh: {'ligado' if auto_refresh else 'desligado'}")

    with st.sidebar:
        st.markdown("### Navegacao")
        page = st.radio(
            "Pagina",
            options=[
                "Resumo operacional",
                "Saude por pipeline",
                "Runs e controle",
                "Auditoria de conexoes",
            ],
            index=0,
        )
        st.caption("Escopo monitorado: entidades e fatos cadastrados no ctl.etl_control")

    preflight = get_preflight_snapshot()
    _render_preflight(preflight)

    if not preflight.get("ready_for_monitoring"):
        return

    try:
        runs_df = _ensure_datetime_columns(
            get_runs(),
            ["started_at", "finished_at"],
        )
        control_df = _ensure_datetime_columns(
            get_control_state(),
            ["watermark_updated_at", "last_success_at", "updated_at"],
        )
        entity_runs_df = _ensure_datetime_columns(
            get_entity_runs(),
            [
                "entity_started_at",
                "entity_finished_at",
                "watermark_from_updated_at",
                "watermark_to_updated_at",
            ],
        )
    except Exception as exc:  # noqa: BLE001
        st.error("Falha ao consultar dados do DW. Verifique conexao e objetos de controle ETL.")
        st.code(str(exc))
        for suggestion in _suggest_connection_fix(str(exc)):
            st.write(f"- {suggestion}")
        if auto_refresh:
            time.sleep(refresh_seconds)
            st.cache_data.clear()
            st.rerun()
        return

    if runs_df.empty and control_df.empty:
        st.warning("Sem dados para exibir. Execute os scripts SQL de controle e rode o ETL ao menos uma vez.")
        if auto_refresh:
            time.sleep(refresh_seconds)
            st.cache_data.clear()
            st.rerun()
        return

    if page == "Resumo operacional":
        _render_kpi_cards(runs_df, control_df, entity_runs_df)
        _render_pipeline_overview_section()
        _render_alerts_sla_section(runs_df, entity_runs_df)
        _render_execution_timeline_section()
        _render_running_section()
        _render_charts_section()
        _render_failures_section(entity_runs_df)
    elif page == "Saude por pipeline":
        _render_pipeline_health_section(control_df)
    elif page == "Runs e controle":
        _render_runs_control_section(runs_df, control_df)
    else:
        _render_connection_audit_section()

    if auto_refresh:
        time.sleep(refresh_seconds)
        st.cache_data.clear()
        st.rerun()


if __name__ == "__main__":
    render_dashboard()
