
from __future__ import annotations

import os
from datetime import date, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

import altair as alt
import pandas as pd
import streamlit as st

try:
    import pyodbc  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    pyodbc = None


VIEW_NAME = "fact.VW_DASH_METAS_R1"

NUMERIC_COLUMNS = [
    "valor_meta",
    "valor_realizado",
    "gap_meta",
    "percentual_atingido",
    "itens_realizados",
    "pedidos_realizados",
]

TEXT_COLUMNS_DEFAULTS: dict[str, str] = {
    "regional": "Sem regional",
    "tipo_equipe": "Nao informado",
    "nome_equipe": "Sem equipe",
    "nome_vendedor": "Sem vendedor",
    "quartil_performance": "Q4",
}

KPI_CATALOG: list[dict[str, str]] = [
    {
        "kpi": "Meta total",
        "formula_prd": "SUM(valor_meta)",
        "fonte": "fact.VW_DASH_METAS_R1.valor_meta",
        "status_prd": "Atendido (PRD 11.1 - metas)",
    },
    {
        "kpi": "Realizado total",
        "formula_prd": "SUM(valor_realizado)",
        "fonte": "fact.VW_DASH_METAS_R1.valor_realizado",
        "status_prd": "Atendido (PRD 11.1 - metas)",
    },
    {
        "kpi": "Percentual de atingimento de meta",
        "formula_prd": "(SUM(valor_realizado) / SUM(valor_meta)) * 100",
        "fonte": "fact.VW_DASH_METAS_R1.valor_realizado, valor_meta",
        "status_prd": "Atendido (PRD 11.1)",
    },
    {
        "kpi": "Gap de meta",
        "formula_prd": "SUM(valor_realizado - valor_meta)",
        "fonte": "fact.VW_DASH_METAS_R1.gap_meta",
        "status_prd": "Atendido (apoio de gestao comercial)",
    },
    {
        "kpi": "Taxa de meta batida",
        "formula_prd": "AVG(CASE WHEN meta_batida=1 THEN 1 ELSE 0 END)",
        "fonte": "fact.VW_DASH_METAS_R1.meta_batida",
        "status_prd": "Extra (operacao comercial R1)",
    },
]


st.set_page_config(
    page_title="Dashboard de Metas R1",
    page_icon=":dart:",
    layout="wide",
)


def _inject_css() -> None:
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Sora:wght@400;500;700;800&family=IBM+Plex+Mono:wght@500&display=swap');

        .stApp {
            background:
                radial-gradient(circle at 8% 2%, rgba(134, 239, 172, 0.36), transparent 38%),
                radial-gradient(circle at 92% 8%, rgba(253, 224, 71, 0.25), transparent 30%),
                linear-gradient(170deg, #f8fafc 0%, #eef2ff 100%);
            color: #1f2937;
            font-family: 'Sora', sans-serif;
        }

        .block-container {
            padding-top: 1.1rem !important;
            padding-bottom: 1.4rem !important;
            max-width: 1480px;
        }

        .hero {
            border-radius: 18px;
            padding: 1rem 1.2rem;
            border: 1px solid rgba(101, 85, 143, 0.20);
            background: linear-gradient(120deg, rgba(255, 255, 255, 0.95) 0%, rgba(236, 253, 245, 0.92) 100%);
            box-shadow: 0 12px 24px rgba(15, 23, 42, 0.06);
            margin-bottom: 0.75rem;
        }

        .hero h1 {
            margin: 0 0 0.28rem 0;
            font-size: 1.45rem;
            line-height: 1.2;
            font-weight: 800;
            color: #0f172a;
        }

        .hero p {
            margin: 0;
            color: #475569;
            font-size: 0.94rem;
            font-weight: 500;
        }

        .card {
            border-radius: 16px;
            padding: 0.7rem 0.88rem 0.38rem 0.88rem;
            border: 1px solid rgba(101, 85, 143, 0.20);
            background: rgba(255, 255, 255, 0.84);
            box-shadow: 0 8px 18px rgba(15, 23, 42, 0.05);
            margin-bottom: 0.8rem;
        }

        [data-testid="stMetricValue"] {
            font-family: 'IBM Plex Mono', monospace;
            letter-spacing: -0.02em;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def _safe_float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _fmt_currency(value: float) -> str:
    masked = f"{value:,.2f}"
    return "R$ " + masked.replace(",", "X").replace(".", ",").replace("X", ".")


def _fmt_int(value: float) -> str:
    masked = f"{int(round(value)):,.0f}"
    return masked.replace(",", ".")


def _fmt_pct(value: float) -> str:
    return f"{value * 100:.1f}%".replace(".", ",")

def _resolve_sql_driver() -> str:
    explicit_driver = os.getenv("DASH_METAS_SQL_DRIVER")
    if explicit_driver:
        return explicit_driver

    installed = []
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
    server = os.getenv("DASH_METAS_SQL_SERVER", "sqlserver")
    port = os.getenv("DASH_METAS_SQL_PORT", "").strip()
    database = os.getenv("DASH_METAS_DW_DB", "DW_ECOMMERCE")
    user = os.getenv("DASH_METAS_SQL_USER", "bi_reader")
    password = os.getenv("DASH_METAS_SQL_PASSWORD", "")
    encrypt = os.getenv("DASH_METAS_SQL_ENCRYPT", "yes")
    trust_server_certificate = os.getenv("DASH_METAS_SQL_TRUST_SERVER_CERTIFICATE", "yes")

    if not password:
        raise ValueError("Variavel `DASH_METAS_SQL_PASSWORD` nao definida para o dashboard.")

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


def _open_connection(conn_str: str):
    if pyodbc is None:
        raise ModuleNotFoundError(
            "Dependencia ausente: pyodbc. Instale com `pip install -r dashboards/streamlit/metas/requirements.txt`."
        )
    timeout = _safe_int(os.getenv("DASH_METAS_SQL_TIMEOUT_SECONDS"), 120)
    connection = pyodbc.connect(conn_str, autocommit=True)
    connection.timeout = timeout
    return connection


def _suggest_connection_fix(error_text: str) -> list[str]:
    upper = error_text.upper()
    suggestions: list[str] = []

    if "IM002" in upper:
        suggestions.append("Driver ODBC nao encontrado. Ajuste `DASH_METAS_SQL_DRIVER` para ODBC 17/18.")
    if "08001" in upper or "SERVER DOES NOT EXIST" in upper:
        suggestions.append("Falha de conexao no servidor. Revise `DASH_METAS_SQL_SERVER` e `DASH_METAS_SQL_PORT`.")
    if "28000" in upper or "LOGIN FAILED" in upper:
        suggestions.append("Falha de autenticacao. Revise `DASH_METAS_SQL_USER` e `DASH_METAS_SQL_PASSWORD`.")
    if "INVALID OBJECT NAME" in upper and "VW_DASH_METAS_R1" in upper:
        suggestions.append("View de metas ausente. Execute `sql/dw/04_views/13_vw_dash_metas_r1.sql`.")
    if "TIMEOUT" in upper or "HYT00" in upper:
        suggestions.append("Timeout de consulta. Reduza o periodo ou valide saude do SQL Server.")
    if not suggestions:
        suggestions.append("Validar conectividade, permissoes do `bi_reader` e existencia da view de consumo.")

    return suggestions


def _build_in_filter(column_name: str, values: tuple[str, ...], params: list[Any]) -> str:
    if not values:
        return ""
    placeholders = ", ".join("?" for _ in values)
    params.extend(values)
    return f" AND {column_name} IN ({placeholders})"


@st.cache_data(ttl=600, show_spinner=False)
def _load_metadata(conn_str: str) -> dict[str, Any]:
    connection = _open_connection(conn_str)
    try:
        bounds = pd.read_sql(
            f"""
            SELECT
                CAST(MIN(data_completa) AS date) AS min_data,
                CAST(MAX(data_completa) AS date) AS max_data
            FROM {VIEW_NAME};
            """,
            connection,
        )
        if bounds.empty or bounds.loc[0, "min_data"] is None or bounds.loc[0, "max_data"] is None:
            raise ValueError("A view de metas nao retornou datas validas.")

        min_data = pd.to_datetime(bounds.loc[0, "min_data"]).date()
        max_data = pd.to_datetime(bounds.loc[0, "max_data"]).date()

        regionais = pd.read_sql(
            f"SELECT DISTINCT regional FROM {VIEW_NAME} WHERE regional IS NOT NULL ORDER BY regional;",
            connection,
        )["regional"].astype(str).tolist()
        equipes = pd.read_sql(
            f"SELECT DISTINCT nome_equipe FROM {VIEW_NAME} WHERE nome_equipe IS NOT NULL ORDER BY nome_equipe;",
            connection,
        )["nome_equipe"].astype(str).tolist()
        vendedores = pd.read_sql(
            f"SELECT DISTINCT nome_vendedor FROM {VIEW_NAME} WHERE nome_vendedor IS NOT NULL ORDER BY nome_vendedor;",
            connection,
        )["nome_vendedor"].astype(str).tolist()
        tipos_equipe = pd.read_sql(
            f"SELECT DISTINCT tipo_equipe FROM {VIEW_NAME} WHERE tipo_equipe IS NOT NULL ORDER BY tipo_equipe;",
            connection,
        )["tipo_equipe"].astype(str).tolist()

        return {
            "min_data": min_data,
            "max_data": max_data,
            "regionais": regionais,
            "equipes": equipes,
            "vendedores": vendedores,
            "tipos_equipe": tipos_equipe,
        }
    finally:
        connection.close()


@st.cache_data(ttl=180, show_spinner=False)
def _load_goals_data(
    conn_str: str,
    start_date: date,
    end_date: date,
    regionais: tuple[str, ...],
    equipes: tuple[str, ...],
    vendedores: tuple[str, ...],
    tipos_equipe: tuple[str, ...],
) -> pd.DataFrame:
    params: list[Any] = [start_date, end_date]
    where = "WHERE CAST(data_completa AS date) BETWEEN ? AND ?"
    where += _build_in_filter("regional", regionais, params)
    where += _build_in_filter("nome_equipe", equipes, params)
    where += _build_in_filter("nome_vendedor", vendedores, params)
    where += _build_in_filter("tipo_equipe", tipos_equipe, params)

    query = f"""
    SELECT
        meta_snapshot_id,
        CAST(data_completa AS date) AS data_completa,
        ano,
        trimestre,
        mes,
        nome_mes,
        regional,
        tipo_equipe,
        nome_equipe,
        vendedor_id,
        nome_vendedor,
        valor_meta,
        valor_realizado,
        gap_meta,
        percentual_atingido,
        meta_batida,
        meta_superada,
        ranking_periodo,
        quartil_performance,
        itens_realizados,
        pedidos_realizados,
        data_atualizacao
    FROM {VIEW_NAME}
    {where};
    """

    connection = _open_connection(conn_str)
    try:
        df = pd.read_sql(query, connection, params=params)
    finally:
        connection.close()

    if df.empty:
        return df

    for column, default_value in TEXT_COLUMNS_DEFAULTS.items():
        if column not in df.columns:
            df[column] = default_value
        df[column] = df[column].fillna(default_value).astype(str)

    for column in NUMERIC_COLUMNS:
        if column not in df.columns:
            df[column] = 0.0
        df[column] = pd.to_numeric(df[column], errors="coerce").fillna(0.0)

    for column in ("meta_batida", "meta_superada"):
        if column not in df.columns:
            df[column] = 0
        df[column] = pd.to_numeric(df[column], errors="coerce").fillna(0).astype(int)

    df["data_completa"] = pd.to_datetime(df["data_completa"], errors="coerce")
    df = df.dropna(subset=["data_completa"]).copy()

    if "data_atualizacao" in df.columns:
        df["data_atualizacao"] = pd.to_datetime(df["data_atualizacao"], errors="coerce")

    return df

def _compute_kpis(df: pd.DataFrame) -> dict[str, float]:
    meta_total = _safe_float(df["valor_meta"].sum())
    realizado_total = _safe_float(df["valor_realizado"].sum())
    gap_total = _safe_float(df["gap_meta"].sum())
    linhas_total = float(len(df))
    linhas_meta_batida = _safe_float(df["meta_batida"].sum())
    linhas_meta_superada = _safe_float(df["meta_superada"].sum())
    vendedores_unicos = float(df["vendedor_id"].nunique()) if "vendedor_id" in df.columns else 0.0

    return {
        "meta_total": meta_total,
        "realizado_total": realizado_total,
        "atingimento_geral": (realizado_total / meta_total) if meta_total > 0 else 0.0,
        "gap_total": gap_total,
        "taxa_meta_batida": (linhas_meta_batida / linhas_total) if linhas_total > 0 else 0.0,
        "taxa_meta_superada": (linhas_meta_superada / linhas_total) if linhas_total > 0 else 0.0,
        "vendedores_unicos": vendedores_unicos,
        "pedidos_realizados": _safe_float(df["pedidos_realizados"].sum()),
    }


def _resolve_local_now() -> tuple[datetime, str]:
    timezone_name = os.getenv("DASH_METAS_TIMEZONE", "America/Sao_Paulo")
    try:
        timezone_obj = ZoneInfo(timezone_name)
    except Exception:  # noqa: BLE001
        timezone_obj = ZoneInfo("UTC")
        timezone_name = "UTC"
    now_local = datetime.now(tz=timezone_obj)
    return now_local, timezone_name


def _evaluate_freshness_status(last_data_date: date) -> dict[str, str]:
    now_local, timezone_name = _resolve_local_now()
    cutoff_dt = datetime.combine(
        last_data_date + timedelta(days=1),
        datetime.min.time(),
        tzinfo=now_local.tzinfo,
    ) + timedelta(hours=8)

    if now_local <= cutoff_dt:
        return {
            "status": "Dentro do SLA",
            "detail": f"Ultima data de negocio {last_data_date.isoformat()} com prazo ate {cutoff_dt.strftime('%Y-%m-%d %H:%M')}.",
            "timezone": timezone_name,
        }

    overdue = now_local - cutoff_dt
    overdue_hours = int(overdue.total_seconds() // 3600)
    return {
        "status": "Atraso de atualizacao",
        "detail": (
            f"Ultima data de negocio {last_data_date.isoformat()} excedeu o prazo D+1 08:00 "
            f"em aproximadamente {overdue_hours}h."
        ),
        "timezone": timezone_name,
    }


def _build_kpi_reference_sql(start_date: date, end_date: date) -> str:
    return f"""
SELECT
    SUM(valor_meta) AS meta_total,
    SUM(valor_realizado) AS realizado_total,
    SUM(valor_realizado) * 1.0 / NULLIF(SUM(valor_meta), 0) AS percentual_atingimento_geral,
    SUM(gap_meta) AS gap_total,
    AVG(CASE WHEN meta_batida = 1 THEN 1.0 ELSE 0.0 END) AS taxa_meta_batida
FROM fact.VW_DASH_METAS_R1
WHERE CAST(data_completa AS date) BETWEEN '{start_date.isoformat()}' AND '{end_date.isoformat()}';
""".strip()


def _delta_pct(current: float, previous: float) -> float | None:
    if abs(previous) < 1e-9:
        return None
    return (current - previous) / abs(previous)


def _fmt_delta(current: float, previous: float) -> str | None:
    delta = _delta_pct(current, previous)
    if delta is None:
        return None
    signal = "+" if delta >= 0 else ""
    return f"{signal}{delta * 100:.1f}%".replace(".", ",")


def _render_kpi_strip(current: dict[str, float], previous: dict[str, float] | None) -> None:
    labels = [
        ("Meta total", "meta_total", _fmt_currency, "normal"),
        ("Realizado total", "realizado_total", _fmt_currency, "normal"),
        ("Atingimento geral", "atingimento_geral", _fmt_pct, "normal"),
        ("Gap total", "gap_total", _fmt_currency, "normal"),
        ("Taxa meta batida", "taxa_meta_batida", _fmt_pct, "normal"),
        ("Taxa meta superada", "taxa_meta_superada", _fmt_pct, "normal"),
        ("Vendedores no recorte", "vendedores_unicos", _fmt_int, "normal"),
        ("Pedidos realizados", "pedidos_realizados", _fmt_int, "normal"),
    ]

    metric_cols = st.columns(4)
    for idx, (label, key, formatter, delta_color) in enumerate(labels):
        target = metric_cols[idx % 4]
        with target:
            delta = None
            if previous is not None and key in previous:
                delta = _fmt_delta(current[key], previous[key])
            st.metric(label=label, value=formatter(current[key]), delta=delta, delta_color=delta_color)


def _line_trend_chart(df: pd.DataFrame) -> alt.Chart:
    grouped = (
        df.groupby("data_completa", as_index=False)
        .agg(meta_total=("valor_meta", "sum"), realizado_total=("valor_realizado", "sum"))
        .sort_values("data_completa")
    )
    melted = grouped.melt(
        id_vars=["data_completa"],
        value_vars=["meta_total", "realizado_total"],
        var_name="indicador",
        value_name="valor",
    )
    return (
        alt.Chart(melted)
        .mark_line(point=True, strokeWidth=2.7)
        .encode(
            x=alt.X("data_completa:T", title="Mes"),
            y=alt.Y("valor:Q", title="Valor"),
            color=alt.Color("indicador:N", scale=alt.Scale(domain=["meta_total", "realizado_total"], range=["#0ea5e9", "#16a34a"])),
            tooltip=[
                alt.Tooltip("data_completa:T", title="Mes"),
                alt.Tooltip("indicador:N", title="Indicador"),
                alt.Tooltip("valor:Q", title="Valor", format=",.2f"),
            ],
        )
        .properties(height=320)
        .interactive()
    )


def _bar_chart(df: pd.DataFrame, category_col: str, value_col: str, color: str, title: str) -> alt.Chart:
    return (
        alt.Chart(df)
        .mark_bar(cornerRadiusTopRight=5, cornerRadiusBottomRight=5, color=color)
        .encode(
            x=alt.X(f"{value_col}:Q", title="Valor"),
            y=alt.Y(f"{category_col}:N", sort="-x", title=title),
            tooltip=[
                alt.Tooltip(f"{category_col}:N", title=title),
                alt.Tooltip(f"{value_col}:Q", title="Valor", format=",.2f"),
            ],
        )
        .properties(height=320)
    )

def _render_metric_dictionary_tab(current_kpis: dict[str, float], start_date: date, end_date: date) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Dicionario de metricas (RF-13)")
    catalog_df = pd.DataFrame(KPI_CATALOG).rename(
        columns={"kpi": "Metrica", "formula_prd": "Formula oficial", "fonte": "Fonte de dados", "status_prd": "Status"}
    )
    st.dataframe(catalog_df, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Valores do periodo selecionado")
    values_df = pd.DataFrame(
        [
            {"Metrica": "Meta total", "Valor no dashboard": _fmt_currency(current_kpis["meta_total"])},
            {"Metrica": "Realizado total", "Valor no dashboard": _fmt_currency(current_kpis["realizado_total"])},
            {"Metrica": "Atingimento geral", "Valor no dashboard": _fmt_pct(current_kpis["atingimento_geral"])},
            {"Metrica": "Gap total", "Valor no dashboard": _fmt_currency(current_kpis["gap_total"])},
            {"Metrica": "Taxa de meta batida", "Valor no dashboard": _fmt_pct(current_kpis["taxa_meta_batida"])},
        ]
    )
    st.dataframe(values_df, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("SQL de referencia para homologacao")
    st.code(_build_kpi_reference_sql(start_date, end_date), language="sql")
    st.markdown("</div>", unsafe_allow_html=True)


def _render_overview_tab(df: pd.DataFrame) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Tendencia mensal: meta vs realizado")
    st.altair_chart(_line_trend_chart(df), use_container_width=True)
    st.markdown("</div>", unsafe_allow_html=True)

    quartil = (
        df.groupby("quartil_performance", as_index=False)
        .size()
        .rename(columns={"size": "total_registros"})
        .sort_values("quartil_performance")
    )
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Distribuicao por quartil de performance")
    quartil_chart = alt.Chart(quartil).mark_bar(color="#7c3aed").encode(
        x=alt.X("quartil_performance:N", title="Quartil"),
        y=alt.Y("total_registros:Q", title="Registros"),
    )
    st.altair_chart(quartil_chart.properties(height=220), use_container_width=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_team_seller_tab(df: pd.DataFrame) -> None:
    equipe = (
        df.groupby(["nome_equipe", "regional"], as_index=False)
        .agg(meta_total=("valor_meta", "sum"), realizado_total=("valor_realizado", "sum"))
    )
    equipe["atingimento"] = equipe.apply(
        lambda row: (row["realizado_total"] / row["meta_total"]) if row["meta_total"] else 0.0,
        axis=1,
    )
    equipe = equipe.sort_values("atingimento", ascending=False)

    vendedor = (
        df.groupby(["nome_vendedor", "nome_equipe"], as_index=False)
        .agg(meta_total=("valor_meta", "sum"), realizado_total=("valor_realizado", "sum"))
    )
    vendedor["atingimento"] = vendedor.apply(
        lambda row: (row["realizado_total"] / row["meta_total"]) if row["meta_total"] else 0.0,
        axis=1,
    )
    vendedor = vendedor.sort_values("atingimento", ascending=False)

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top equipes por atingimento")
        st.altair_chart(_bar_chart(equipe.head(12), "nome_equipe", "atingimento", "#0f766e", "Equipe"), use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top vendedores por atingimento")
        st.altair_chart(_bar_chart(vendedor.head(12), "nome_vendedor", "atingimento", "#b45309", "Vendedor"), use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)


def _render_data_tab(df: pd.DataFrame) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Base consolidada")

    export_cols = [
        "data_completa",
        "regional",
        "tipo_equipe",
        "nome_equipe",
        "nome_vendedor",
        "valor_meta",
        "valor_realizado",
        "gap_meta",
        "percentual_atingido",
        "meta_batida",
        "meta_superada",
        "ranking_periodo",
        "quartil_performance",
        "pedidos_realizados",
        "itens_realizados",
    ]
    show = df[[col for col in export_cols if col in df.columns]].sort_values(["data_completa", "valor_realizado"], ascending=[False, False]).copy()
    show["data_completa"] = show["data_completa"].dt.strftime("%Y-%m-%d")

    csv_data = show.to_csv(index=False).encode("utf-8")
    st.download_button(
        "Baixar CSV filtrado",
        data=csv_data,
        file_name=f"dash_metas_filtrado_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        mime="text/csv",
    )
    st.dataframe(show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def main() -> None:
    _inject_css()

    st.markdown(
        """
        <div class="hero">
            <h1>Dashboard de Metas R1</h1>
            <p>Camada de consumo certificada em <code>fact.VW_DASH_METAS_R1</code> para meta, realizado e atingimento.</p>
        </div>
        """,
        unsafe_allow_html=True,
    )

    try:
        conn_str = _build_conn_str()
        metadata = _load_metadata(conn_str)
    except Exception as exc:  # noqa: BLE001
        st.error("Nao foi possivel inicializar o dashboard de metas.")
        st.code(str(exc))
        for suggestion in _suggest_connection_fix(str(exc)):
            st.write(f"- {suggestion}")
        st.stop()

    min_data = metadata["min_data"]
    max_data = metadata["max_data"]
    default_start = max(min_data, max_data - timedelta(days=365))

    with st.sidebar:
        st.header("Filtros")
        selected_period = st.date_input(
            "Periodo",
            value=(default_start, max_data),
            min_value=min_data,
            max_value=max_data,
            format="YYYY-MM-DD",
        )
        if not isinstance(selected_period, tuple) or len(selected_period) != 2:
            start_date, end_date = default_start, max_data
        else:
            start_date, end_date = selected_period
            if start_date > end_date:
                start_date, end_date = end_date, start_date

        selected_regionais = tuple(st.multiselect("Regional", metadata["regionais"]))
        selected_tipos_equipe = tuple(st.multiselect("Tipo de equipe", metadata["tipos_equipe"]))
        selected_equipes = tuple(st.multiselect("Equipe", metadata["equipes"]))
        selected_vendedores = tuple(st.multiselect("Vendedor", metadata["vendedores"]))
        compare_previous = st.toggle("Comparar com periodo anterior", value=True)

        if st.button("Atualizar dados", use_container_width=True):
            st.cache_data.clear()
            st.rerun()

    with st.spinner("Consultando metas no DW..."):
        try:
            df = _load_goals_data(
                conn_str=conn_str,
                start_date=start_date,
                end_date=end_date,
                regionais=selected_regionais,
                equipes=selected_equipes,
                vendedores=selected_vendedores,
                tipos_equipe=selected_tipos_equipe,
            )
        except Exception as exc:  # noqa: BLE001
            st.error("Falha ao consultar os dados da view de metas.")
            st.code(str(exc))
            for suggestion in _suggest_connection_fix(str(exc)):
                st.write(f"- {suggestion}")
            st.stop()

    if df.empty:
        st.warning("Sem dados para os filtros atuais. Ajuste periodo e filtros laterais.")
        st.stop()

    previous_kpis: dict[str, float] | None = None
    if compare_previous:
        days = (end_date - start_date).days + 1
        prev_end = start_date - timedelta(days=1)
        prev_start = prev_end - timedelta(days=days - 1)
        prev_df = _load_goals_data(
            conn_str=conn_str,
            start_date=prev_start,
            end_date=prev_end,
            regionais=selected_regionais,
            equipes=selected_equipes,
            vendedores=selected_vendedores,
            tipos_equipe=selected_tipos_equipe,
        )
        if not prev_df.empty:
            previous_kpis = _compute_kpis(prev_df)

    current_kpis = _compute_kpis(df)
    freshness = _evaluate_freshness_status(max_data)

    updated_at = None
    if "data_atualizacao" in df.columns:
        updated_at = df["data_atualizacao"].max()

    c_period, c_update, c_sla = st.columns([2.1, 1.2, 1.7])
    with c_period:
        st.caption(f"Periodo ativo: {start_date.isoformat()} a {end_date.isoformat()}")
    with c_update:
        if pd.notna(updated_at):
            st.caption(f"Ultima atualizacao: {pd.to_datetime(updated_at).strftime('%Y-%m-%d %H:%M:%S')}")
    with c_sla:
        if freshness["status"] == "Dentro do SLA":
            st.success(f"{freshness['status']} ({freshness['timezone']})")
        else:
            st.warning(f"{freshness['status']} ({freshness['timezone']})")
        st.caption(freshness["detail"])

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    _render_kpi_strip(current_kpis, previous_kpis)
    st.markdown("</div>", unsafe_allow_html=True)

    tab_overview, tab_team, tab_metrics, tab_data = st.tabs(
        ["Visao geral", "Equipes e vendedores", "Metricas (PRD)", "Base detalhada"]
    )

    with tab_overview:
        _render_overview_tab(df)

    with tab_team:
        _render_team_seller_tab(df)

    with tab_metrics:
        _render_metric_dictionary_tab(current_kpis, start_date, end_date)

    with tab_data:
        _render_data_tab(df)


if __name__ == "__main__":
    main()
