from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pandas as pd
import streamlit as st


ETL_DIR = Path(__file__).resolve().parents[1]
if str(ETL_DIR) not in sys.path:
    sys.path.append(str(ETL_DIR))

from config import ETLConfig  # noqa: E402
from db import close_quietly, connect_sqlserver, query_all  # noqa: E402


st.set_page_config(
    page_title="ETL Monitor - DW E-commerce",
    page_icon=":bar_chart:",
    layout="wide",
)


def _to_dataframe(rows: list[dict[str, Any]]) -> pd.DataFrame:
    if not rows:
        return pd.DataFrame()
    return pd.DataFrame(rows)


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


@st.cache_data(ttl=30)
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


@st.cache_data(ttl=30)
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


@st.cache_data(ttl=30)
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


@st.cache_data(ttl=30)
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


@st.cache_data(ttl=60)
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


@st.cache_data(ttl=60)
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


def _ensure_datetime_columns(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    if df.empty:
        return df
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def render_dashboard() -> None:
    st.title("ETL Monitor - DW E-commerce")
    st.caption("Acompanhamento visual dos runs ETL (audit.* e ctl.etl_control).")

    col_a, col_b = st.columns([1, 1])
    with col_a:
        if st.button("Atualizar agora"):
            st.cache_data.clear()
            st.rerun()
    with col_b:
        st.caption(f"Atualizado em UTC: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}")

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
        return

    if runs_df.empty and control_df.empty:
        st.warning("Sem dados para exibir. Execute os scripts SQL de controle e rode o ETL ao menos uma vez.")
        return

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

    st.subheader("Controle incremental (ctl.etl_control)")
    st.dataframe(control_df, use_container_width=True, hide_index=True)

    st.subheader("Ultimos runs (audit.etl_run)")
    st.dataframe(runs_df, use_container_width=True, hide_index=True)

    if not runs_df.empty:
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

    st.subheader("Falhas recentes por entidade")
    if entity_runs_df.empty:
        st.info("Sem falhas registradas.")
    else:
        failures = entity_runs_df[entity_runs_df["status"] == "failed"].copy()
        if failures.empty:
            st.success("Nenhuma falha encontrada no historico carregado.")
        else:
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


if __name__ == "__main__":
    render_dashboard()
