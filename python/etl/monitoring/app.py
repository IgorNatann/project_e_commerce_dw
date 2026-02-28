from __future__ import annotations

import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

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
    if "PERMISSION" in upper_error or "DENIED" in upper_error:
        suggestions.append("Permissao insuficiente para consulta. Revise grants do usuario de monitoramento.")

    if not suggestions:
        suggestions.append("Revise a string de conexao e confirme que os scripts SQL de controle ETL foram executados.")

    return suggestions


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


@st.cache_data(ttl=20)
def get_preflight_snapshot() -> dict[str, Any]:
    config = ETLConfig.from_env()
    snapshot: dict[str, Any] = {
        "connection_ok": False,
        "ready_for_monitoring": False,
        "ready_for_first_run": False,
        "db_name": None,
        "server_name": None,
        "driver": _extract_conn_attr(config.dw_conn_str, "Driver"),
        "masked_conn_str": _mask_conn_str(config.dw_conn_str),
        "has_schema_ctl": False,
        "has_schema_audit": False,
        "has_ctl_etl_control": False,
        "has_audit_etl_run": False,
        "has_audit_etl_run_entity": False,
        "has_dim_cliente_table": False,
        "has_dim_cliente_active": False,
        "oltp_connection_ok": False,
        "has_core_customers_table": False,
        "control_entities": 0,
        "active_entities": 0,
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
            CASE WHEN OBJECT_ID('audit.etl_run_entity', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_audit_etl_run_entity,
            CASE WHEN OBJECT_ID('dim.DIM_CLIENTE', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_dim_cliente_table;
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
        snapshot["has_dim_cliente_table"] = _to_bool(base_info.get("has_dim_cliente_table"))

        if snapshot["has_ctl_etl_control"]:
            control_counts = query_one(
                connection,
                """
                SELECT
                    COUNT(*) AS control_entities,
                    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_entities,
                    SUM(CASE WHEN entity_name = 'dim_cliente' AND is_active = 1 THEN 1 ELSE 0 END) AS dim_cliente_active
                FROM ctl.etl_control;
                """,
            )
            if control_counts:
                snapshot["control_entities"] = _to_int(control_counts.get("control_entities"), 0)
                snapshot["active_entities"] = _to_int(control_counts.get("active_entities"), 0)
                snapshot["has_dim_cliente_active"] = _to_int(control_counts.get("dim_cliente_active"), 0) > 0

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
            source_check = query_one(
                oltp_connection,
                """
                SELECT CASE WHEN OBJECT_ID('core.customers', 'U') IS NOT NULL THEN 1 ELSE 0 END AS has_core_customers_table;
                """,
            )
            if source_check:
                snapshot["has_core_customers_table"] = _to_bool(source_check.get("has_core_customers_table"))
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
        snapshot["ready_for_first_run"] = (
            snapshot["ready_for_monitoring"]
            and snapshot["has_dim_cliente_table"]
            and snapshot["has_dim_cliente_active"]
            and snapshot["oltp_connection_ok"]
            and snapshot["has_core_customers_table"]
        )

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

        a, b, c = st.columns(3)
        a.metric("Conexao DW", _status_badge(bool(snapshot["connection_ok"])))
        b.metric("Conexao OLTP", _status_badge(bool(snapshot["oltp_connection_ok"])))
        c.metric("Dim Cliente pronta", _status_badge(bool(snapshot["ready_for_first_run"])))

        details_left, details_right = st.columns(2)
        with details_left:
            st.write(f"- server: `{snapshot.get('server_name') or 'N/A'}`")
            st.write(f"- database: `{snapshot.get('db_name') or 'N/A'}`")
            st.write(f"- driver: `{snapshot.get('driver') or 'N/A'}`")
            st.write(f"- entities cadastradas: `{snapshot.get('control_entities', 0)}`")
            st.write(f"- entities ativas: `{snapshot.get('active_entities', 0)}`")
            st.write(f"- runs historicos: `{snapshot.get('run_count', 0)}`")
            st.write(f"- dim_cliente ativa: `{_status_badge(bool(snapshot.get('has_dim_cliente_active')))} `")

        with details_right:
            st.write(f"- schema ctl: `{_status_badge(bool(snapshot['has_schema_ctl']))}`")
            st.write(f"- schema audit: `{_status_badge(bool(snapshot['has_schema_audit']))}`")
            st.write(f"- tabela ctl.etl_control: `{_status_badge(bool(snapshot['has_ctl_etl_control']))}`")
            st.write(f"- tabela audit.etl_run: `{_status_badge(bool(snapshot['has_audit_etl_run']))}`")
            st.write(f"- tabela audit.etl_run_entity: `{_status_badge(bool(snapshot['has_audit_etl_run_entity']))}`")
            st.write(f"- tabela dim.DIM_CLIENTE: `{_status_badge(bool(snapshot.get('has_dim_cliente_table')))} `")
            st.write(f"- tabela core.customers: `{_status_badge(bool(snapshot.get('has_core_customers_table')))} `")

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
        elif not snapshot.get("ready_for_first_run"):
            st.info("Monitoramento pronto, mas o escopo `dim_cliente` ainda nao esta totalmente validado.")
        else:
            st.success("Pre-flight concluido. Ambiente pronto para validar `dim_cliente`.")


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


def _ensure_datetime_columns(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    if df.empty:
        return df
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def _render_kpi_cards(runs_df: pd.DataFrame, control_df: pd.DataFrame, entity_runs_df: pd.DataFrame) -> None:
    latest_run = runs_df.iloc[0] if not runs_df.empty else None
    active_entities = int((control_df["is_active"] == 1).sum()) if "is_active" in control_df.columns else 0

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    last_24h_cutoff = now_utc - timedelta(hours=24)
    failed_last_24h = 0
    if not entity_runs_df.empty and "entity_started_at" in entity_runs_df.columns:
        failed_last_24h = int(
            (
                (entity_runs_df["status"] == "failed")
                & (entity_runs_df["entity_started_at"] >= last_24h_cutoff)
            ).sum()
        )

    metric_1, metric_2, metric_3, metric_4 = st.columns(4)
    metric_1.metric("Entidades ativas", active_entities)
    metric_2.metric("Falhas (24h)", failed_last_24h)
    if latest_run is not None:
        metric_3.metric("Ultimo run_id", int(latest_run["run_id"]))
        metric_4.metric("Status ultimo run", str(latest_run["status"]))
    else:
        metric_3.metric("Ultimo run_id", "-")
        metric_4.metric("Status ultimo run", "-")


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

    st.dataframe(
        failures[
            [
                "run_id",
                "entity_name",
                "entity_started_at",
                "entity_finished_at",
                "error_message",
            ]
        ],
        use_container_width=True,
        hide_index=True,
    )


def _render_connection_audit_section() -> None:
    st.subheader("Auditoria de conexoes SQL")
    conn_col_1, conn_col_2 = st.columns(2)
    with conn_col_1:
        st.markdown("**Eventos por hora (ultimas 24h)**")
        hourly_df = _ensure_datetime_columns(get_connection_audit_hourly(24), ["event_hour_utc"])
        if hourly_df.empty:
            st.info("Sem eventos de conexao capturados no periodo.")
        else:
            chart_df = hourly_df.set_index("event_hour_utc")[["total_events"]]
            st.line_chart(chart_df)
    with conn_col_2:
        st.markdown("**Top logins (ultimas 24h)**")
        login_df = _ensure_datetime_columns(get_connection_audit_logins(24), ["last_event_utc"])
        if login_df.empty:
            st.info("Sem eventos de login no periodo.")
        else:
            st.dataframe(login_df, use_container_width=True, hide_index=True)

    st.markdown("**Eventos recentes de conexao**")
    conn_recent_df = _ensure_datetime_columns(
        get_connection_audit_recent(150),
        ["event_time_utc", "login_time"],
    )
    if conn_recent_df.empty:
        st.info("Nenhum evento recente de conexao.")
    else:
        st.dataframe(conn_recent_df, use_container_width=True, hide_index=True)


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
                "Saude dim_cliente",
                "Runs e controle",
                "Auditoria de conexoes",
            ],
            index=0,
        )
        st.caption("Escopo atual validado: dim_cliente")

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
        _render_running_section()
        _render_charts_section()
        _render_failures_section(entity_runs_df)
    elif page == "Saude dim_cliente":
        _render_dim_cliente_section()
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
