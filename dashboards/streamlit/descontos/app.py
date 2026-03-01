from __future__ import annotations

import os
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import altair as alt
import pandas as pd
import streamlit as st

try:
    import pyodbc  # type: ignore
except ImportError:  # pragma: no cover
    pyodbc = None


VIEW_NAME = "fact.VW_DASH_DESCONTOS_R1"
DEFAULT_SNAPSHOT_FILE = "descontos_r1.csv.gz"

NUMERIC_COLUMNS = [
    "valor_sem_desconto",
    "valor_desconto_aplicado",
    "valor_com_desconto",
    "percentual_desconto_efetivo",
    "margem_antes_desconto",
    "margem_apos_desconto",
    "impacto_margem",
    "roi_desconto",
    "impacto_margem_pct_receita",
]

TEXT_COLUMNS_DEFAULTS: dict[str, str] = {
    "codigo_desconto": "Nao informado",
    "nome_campanha": "Nao informado",
    "tipo_desconto": "Nao informado",
    "metodo_desconto": "Nao informado",
    "origem_campanha": "Nao informado",
    "canal_divulgacao": "Nao informado",
    "nivel_aplicacao": "Nao informado",
    "status_margem": "Nao informado",
    "regiao_pais": "Nao informado",
}

KPI_CATALOG: list[dict[str, str]] = [
    {
        "kpi": "Desconto total concedido",
        "formula_prd": "SUM(valor_desconto_aplicado)",
        "fonte": "fact.VW_DASH_DESCONTOS_R1.valor_desconto_aplicado",
        "status_prd": "Atendido (PRD 11.1 - descontos/ROI)",
    },
    {
        "kpi": "Receita com desconto",
        "formula_prd": "SUM(valor_com_desconto)",
        "fonte": "fact.VW_DASH_DESCONTOS_R1.valor_com_desconto",
        "status_prd": "Atendido (PRD 11.1 - descontos/ROI)",
    },
    {
        "kpi": "ROI ponderado",
        "formula_prd": "(SUM(valor_com_desconto)-SUM(valor_desconto_aplicado))/SUM(valor_desconto_aplicado)",
        "fonte": "fact.VW_DASH_DESCONTOS_R1.valor_com_desconto, valor_desconto_aplicado",
        "status_prd": "Atendido (PRD 11.1 - ROI)",
    },
    {
        "kpi": "Impacto total de margem",
        "formula_prd": "SUM(impacto_margem)",
        "fonte": "fact.VW_DASH_DESCONTOS_R1.impacto_margem",
        "status_prd": "Atendido (PRD 11.1 - impacto de margem)",
    },
    {
        "kpi": "Taxa de aprovacao de desconto",
        "formula_prd": "AVG(CASE WHEN desconto_aprovado=1 THEN 1 ELSE 0 END)",
        "fonte": "fact.VW_DASH_DESCONTOS_R1.desconto_aprovado",
        "status_prd": "Extra (monitoria operacional de desconto)",
    },
]


st.set_page_config(
    page_title="Dashboard de Descontos e ROI R1",
    page_icon=":money_with_wings:",
    layout="wide",
)


def _inject_css() -> None:
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;700;800&family=Space+Mono:wght@700&display=swap');

        .stApp {
            background:
                radial-gradient(circle at 8% 2%, rgba(251, 191, 36, 0.30), transparent 35%),
                radial-gradient(circle at 92% 8%, rgba(16, 185, 129, 0.24), transparent 30%),
                linear-gradient(165deg, #fffaf0 0%, #f8fafc 100%);
            color: #1f2937;
            font-family: 'Archivo', sans-serif;
        }

        .block-container {
            padding-top: 1.1rem !important;
            padding-bottom: 1.4rem !important;
            max-width: 1480px;
        }

        .hero {
            border-radius: 18px;
            padding: 1rem 1.2rem;
            border: 1px solid rgba(120, 53, 15, 0.18);
            background: linear-gradient(120deg, rgba(255, 255, 255, 0.95) 0%, rgba(254, 243, 199, 0.55) 100%);
            box-shadow: 0 12px 24px rgba(15, 23, 42, 0.06);
            margin-bottom: 0.75rem;
        }

        .hero h1 {
            margin: 0 0 0.28rem 0;
            font-size: 1.45rem;
            line-height: 1.2;
            font-weight: 800;
            color: #111827;
        }

        .hero p {
            margin: 0;
            color: #4b5563;
            font-size: 0.94rem;
            font-weight: 500;
        }

        .card {
            border-radius: 16px;
            padding: 0.7rem 0.88rem 0.38rem 0.88rem;
            border: 1px solid rgba(120, 53, 15, 0.18);
            background: rgba(255, 255, 255, 0.84);
            box-shadow: 0 8px 18px rgba(15, 23, 42, 0.05);
            margin-bottom: 0.8rem;
        }

        [data-testid="stMetricValue"] {
            font-family: 'Space Mono', monospace;
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


def _to_bool(raw_value: str | None, default: bool = False) -> bool:
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "t", "yes", "y", "on"}


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _resolve_snapshot_path(env_name: str, default_filename: str) -> str:
    raw_path = os.getenv(env_name, "").strip()
    if raw_path:
        candidate = Path(raw_path)
        resolved = candidate if candidate.is_absolute() else (_repo_root() / candidate)
    else:
        resolved = _repo_root() / "data" / "snapshots" / default_filename
    return str(resolved.resolve())


def _use_snapshot_mode() -> bool:
    generic_value = os.getenv("USE_SNAPSHOT")
    if generic_value is not None:
        return _to_bool(generic_value, default=False)
    return _to_bool(os.getenv("DASH_DESC_USE_SNAPSHOT", "false"), default=False)


def _snapshot_generated_at(snapshot_path: str) -> str | None:
    path = Path(snapshot_path)
    if not path.exists():
        return None
    ts = datetime.fromtimestamp(path.stat().st_mtime)
    return ts.strftime("%Y-%m-%d %H:%M:%S")


@st.cache_data(ttl=600, show_spinner=False)
def _load_snapshot_frame(snapshot_path: str) -> pd.DataFrame:
    path = Path(snapshot_path)
    if not path.exists():
        raise FileNotFoundError(f"Snapshot nao encontrado: {path}")

    suffix = path.suffix.lower()
    if suffix == ".parquet":
        return pd.read_parquet(path)
    if suffix == ".csv" or str(path).lower().endswith(".csv.gz"):
        return pd.read_csv(path, low_memory=False)

    raise ValueError(
        f"Formato de snapshot nao suportado: {path.name}. Use .csv, .csv.gz ou .parquet."
    )


def _normalize_discount_df(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df.copy()

    normalized = df.copy()
    for column, default_value in TEXT_COLUMNS_DEFAULTS.items():
        if column not in normalized.columns:
            normalized[column] = default_value
        normalized[column] = normalized[column].fillna(default_value).astype(str)

    for column in NUMERIC_COLUMNS:
        if column not in normalized.columns:
            normalized[column] = 0.0
        normalized[column] = pd.to_numeric(normalized[column], errors="coerce").fillna(0.0)

    if "desconto_aprovado" not in normalized.columns:
        normalized["desconto_aprovado"] = 0
    normalized["desconto_aprovado"] = pd.to_numeric(normalized["desconto_aprovado"], errors="coerce").fillna(0).astype(int)

    if "data_completa" not in normalized.columns:
        raise ValueError("Coluna `data_completa` nao encontrada na view de consumo.")
    normalized["data_completa"] = pd.to_datetime(normalized["data_completa"], errors="coerce")
    normalized = normalized.dropna(subset=["data_completa"]).copy()

    if "data_atualizacao" in normalized.columns:
        normalized["data_atualizacao"] = pd.to_datetime(normalized["data_atualizacao"], errors="coerce")

    return normalized


def _fmt_currency(value: float) -> str:
    masked = f"{value:,.2f}"
    return "R$ " + masked.replace(",", "X").replace(".", ",").replace("X", ".")


def _fmt_int(value: float) -> str:
    masked = f"{int(round(value)):,.0f}"
    return masked.replace(",", ".")


def _fmt_pct(value: float) -> str:
    return f"{value * 100:.1f}%".replace(".", ",")


def _fmt_roi(value: float) -> str:
    return f"{value:.2f}x".replace(".", ",")


def _resolve_sql_driver() -> str:
    explicit_driver = os.getenv("DASH_DESC_SQL_DRIVER")
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
    server = os.getenv("DASH_DESC_SQL_SERVER", "sqlserver")
    port = os.getenv("DASH_DESC_SQL_PORT", "").strip()
    database = os.getenv("DASH_DESC_DW_DB", "DW_ECOMMERCE")
    user = os.getenv("DASH_DESC_SQL_USER", "bi_reader")
    password = os.getenv("DASH_DESC_SQL_PASSWORD", "")
    encrypt = os.getenv("DASH_DESC_SQL_ENCRYPT", "yes")
    trust_server_certificate = os.getenv("DASH_DESC_SQL_TRUST_SERVER_CERTIFICATE", "yes")

    if not password:
        raise ValueError("Variavel `DASH_DESC_SQL_PASSWORD` nao definida para o dashboard.")

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
            "Dependencia ausente: pyodbc. Instale com `pip install -r dashboards/streamlit/descontos/requirements.txt`."
        )
    timeout = _safe_int(os.getenv("DASH_DESC_SQL_TIMEOUT_SECONDS"), 120)
    connection = pyodbc.connect(conn_str, autocommit=True)
    connection.timeout = timeout
    return connection


def _suggest_connection_fix(error_text: str) -> list[str]:
    upper = error_text.upper()
    suggestions: list[str] = []

    if "IM002" in upper:
        suggestions.append("Driver ODBC nao encontrado. Ajuste `DASH_DESC_SQL_DRIVER` para ODBC 17/18.")
    if "08001" in upper or "SERVER DOES NOT EXIST" in upper:
        suggestions.append("Falha de conexao no servidor. Revise `DASH_DESC_SQL_SERVER` e `DASH_DESC_SQL_PORT`.")
    if "28000" in upper or "LOGIN FAILED" in upper:
        suggestions.append("Falha de autenticacao. Revise `DASH_DESC_SQL_USER` e `DASH_DESC_SQL_PASSWORD`.")
    if "INVALID OBJECT NAME" in upper and "VW_DASH_DESCONTOS_R1" in upper:
        suggestions.append("View de descontos ausente. Execute `sql/dw/04_views/14_vw_dash_descontos_r1.sql`.")
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
            raise ValueError("A view de descontos nao retornou datas validas.")

        min_data = pd.to_datetime(bounds.loc[0, "min_data"]).date()
        max_data = pd.to_datetime(bounds.loc[0, "max_data"]).date()

        regioes = pd.read_sql(
            f"SELECT DISTINCT regiao_pais FROM {VIEW_NAME} WHERE regiao_pais IS NOT NULL ORDER BY regiao_pais;",
            connection,
        )["regiao_pais"].astype(str).tolist()
        tipos = pd.read_sql(
            f"SELECT DISTINCT tipo_desconto FROM {VIEW_NAME} WHERE tipo_desconto IS NOT NULL ORDER BY tipo_desconto;",
            connection,
        )["tipo_desconto"].astype(str).tolist()
        metodos = pd.read_sql(
            f"SELECT DISTINCT metodo_desconto FROM {VIEW_NAME} WHERE metodo_desconto IS NOT NULL ORDER BY metodo_desconto;",
            connection,
        )["metodo_desconto"].astype(str).tolist()
        codigos = pd.read_sql(
            f"SELECT DISTINCT codigo_desconto FROM {VIEW_NAME} WHERE codigo_desconto IS NOT NULL ORDER BY codigo_desconto;",
            connection,
        )["codigo_desconto"].astype(str).tolist()
        niveis = pd.read_sql(
            f"SELECT DISTINCT nivel_aplicacao FROM {VIEW_NAME} WHERE nivel_aplicacao IS NOT NULL ORDER BY nivel_aplicacao;",
            connection,
        )["nivel_aplicacao"].astype(str).tolist()

        return {
            "min_data": min_data,
            "max_data": max_data,
            "regioes": regioes,
            "tipos_desconto": tipos,
            "metodos_desconto": metodos,
            "codigos_desconto": codigos,
            "niveis_aplicacao": niveis,
        }
    finally:
        connection.close()


@st.cache_data(ttl=600, show_spinner=False)
def _load_metadata_snapshot(snapshot_path: str) -> dict[str, Any]:
    df = _normalize_discount_df(_load_snapshot_frame(snapshot_path))
    if df.empty:
        raise ValueError("Snapshot de descontos vazio. Gere um novo snapshot para continuar.")

    min_data = pd.to_datetime(df["data_completa"].min()).date()
    max_data = pd.to_datetime(df["data_completa"].max()).date()

    def _distinct_values(column: str) -> list[str]:
        if column not in df.columns:
            return []
        values = df[column].dropna().astype(str).str.strip()
        values = values[values != ""]
        return sorted(values.unique().tolist())

    return {
        "min_data": min_data,
        "max_data": max_data,
        "regioes": _distinct_values("regiao_pais"),
        "tipos_desconto": _distinct_values("tipo_desconto"),
        "metodos_desconto": _distinct_values("metodo_desconto"),
        "codigos_desconto": _distinct_values("codigo_desconto"),
        "niveis_aplicacao": _distinct_values("nivel_aplicacao"),
    }


@st.cache_data(ttl=180, show_spinner=False)
def _load_discount_data(
    conn_str: str,
    start_date: date,
    end_date: date,
    regioes: tuple[str, ...],
    tipos_desconto: tuple[str, ...],
    metodos_desconto: tuple[str, ...],
    codigos_desconto: tuple[str, ...],
    niveis_aplicacao: tuple[str, ...],
) -> pd.DataFrame:
    params: list[Any] = [start_date, end_date]
    where = "WHERE CAST(data_completa AS date) BETWEEN ? AND ?"
    where += _build_in_filter("regiao_pais", regioes, params)
    where += _build_in_filter("tipo_desconto", tipos_desconto, params)
    where += _build_in_filter("metodo_desconto", metodos_desconto, params)
    where += _build_in_filter("codigo_desconto", codigos_desconto, params)
    where += _build_in_filter("nivel_aplicacao", niveis_aplicacao, params)

    query = f"""
    SELECT
        desconto_aplicado_id,
        CAST(data_completa AS date) AS data_completa,
        ano,
        trimestre,
        mes,
        nome_mes,
        codigo_desconto,
        nome_campanha,
        tipo_desconto,
        metodo_desconto,
        origem_campanha,
        canal_divulgacao,
        nivel_aplicacao,
        regiao_pais,
        status_margem,
        valor_sem_desconto,
        valor_desconto_aplicado,
        valor_com_desconto,
        percentual_desconto_efetivo,
        margem_antes_desconto,
        margem_apos_desconto,
        impacto_margem,
        desconto_aprovado,
        roi_desconto,
        impacto_margem_pct_receita,
        data_atualizacao
    FROM {VIEW_NAME}
    {where};
    """

    connection = _open_connection(conn_str)
    try:
        df = pd.read_sql(query, connection, params=params)
    finally:
        connection.close()

    return _normalize_discount_df(df)


@st.cache_data(ttl=180, show_spinner=False)
def _load_discount_data_snapshot(
    snapshot_path: str,
    start_date: date,
    end_date: date,
    regioes: tuple[str, ...],
    tipos_desconto: tuple[str, ...],
    metodos_desconto: tuple[str, ...],
    codigos_desconto: tuple[str, ...],
    niveis_aplicacao: tuple[str, ...],
) -> pd.DataFrame:
    df = _normalize_discount_df(_load_snapshot_frame(snapshot_path))
    if df.empty:
        return df.copy()

    data_date = df["data_completa"].dt.date
    mask = (data_date >= start_date) & (data_date <= end_date)

    if regioes:
        mask &= df["regiao_pais"].isin(regioes)
    if tipos_desconto:
        mask &= df["tipo_desconto"].isin(tipos_desconto)
    if metodos_desconto:
        mask &= df["metodo_desconto"].isin(metodos_desconto)
    if codigos_desconto:
        mask &= df["codigo_desconto"].isin(codigos_desconto)
    if niveis_aplicacao:
        mask &= df["nivel_aplicacao"].isin(niveis_aplicacao)

    return df.loc[mask].copy()


def _compute_kpis(df: pd.DataFrame) -> dict[str, float]:
    desconto_total = _safe_float(df["valor_desconto_aplicado"].sum())
    receita_total = _safe_float(df["valor_com_desconto"].sum())
    impacto_margem = _safe_float(df["impacto_margem"].sum())
    aplicacoes = float(len(df))
    aprovados = _safe_float(df["desconto_aprovado"].sum())
    roi_medio = _safe_float(df["roi_desconto"].mean()) if len(df) > 0 else 0.0
    desconto_medio_pct = _safe_float(df["percentual_desconto_efetivo"].mean()) / 100.0 if len(df) > 0 else 0.0

    return {
        "aplicacoes": aplicacoes,
        "desconto_total": desconto_total,
        "receita_total": receita_total,
        "roi_ponderado": ((receita_total - desconto_total) / desconto_total) if desconto_total > 0 else 0.0,
        "roi_medio": roi_medio,
        "impacto_margem_total": impacto_margem,
        "impacto_margem_pct_receita": (impacto_margem / receita_total) if receita_total > 0 else 0.0,
        "taxa_aprovacao": (aprovados / aplicacoes) if aplicacoes > 0 else 0.0,
        "desconto_medio_pct": desconto_medio_pct,
    }


def _resolve_local_now() -> tuple[datetime, str]:
    timezone_name = os.getenv("DASH_DESC_TIMEZONE", "America/Sao_Paulo")
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
    COUNT(*) AS total_aplicacoes_desconto,
    SUM(valor_desconto_aplicado) AS desconto_total_concedido,
    SUM(valor_com_desconto) AS receita_com_desconto,
    AVG(roi_desconto) AS roi_medio,
    (SUM(valor_com_desconto) - SUM(valor_desconto_aplicado)) * 1.0
        / NULLIF(SUM(valor_desconto_aplicado), 0) AS roi_ponderado,
    SUM(impacto_margem) AS impacto_margem_total
FROM fact.VW_DASH_DESCONTOS_R1
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
        ("Aplicacoes", "aplicacoes", _fmt_int, "normal"),
        ("Desconto concedido", "desconto_total", _fmt_currency, "inverse"),
        ("Receita com desconto", "receita_total", _fmt_currency, "normal"),
        ("ROI ponderado", "roi_ponderado", _fmt_roi, "normal"),
        ("ROI medio", "roi_medio", _fmt_roi, "normal"),
        ("Impacto de margem", "impacto_margem_total", _fmt_currency, "inverse"),
        ("Impacto margem / receita", "impacto_margem_pct_receita", _fmt_pct, "inverse"),
        ("Taxa de aprovacao", "taxa_aprovacao", _fmt_pct, "normal"),
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
    monthly = (
        df.groupby("data_completa", as_index=False)
        .agg(
            desconto_total=("valor_desconto_aplicado", "sum"),
            receita_total=("valor_com_desconto", "sum"),
        )
        .sort_values("data_completa")
    )
    melted = monthly.melt(
        id_vars=["data_completa"],
        value_vars=["desconto_total", "receita_total"],
        var_name="indicador",
        value_name="valor",
    )
    return (
        alt.Chart(melted)
        .mark_line(point=True, strokeWidth=2.7)
        .encode(
            x=alt.X("data_completa:T", title="Mes"),
            y=alt.Y("valor:Q", title="Valor"),
            color=alt.Color(
                "indicador:N",
                scale=alt.Scale(domain=["desconto_total", "receita_total"], range=["#b45309", "#047857"]),
            ),
            tooltip=[
                alt.Tooltip("data_completa:T", title="Mes"),
                alt.Tooltip("indicador:N", title="Indicador"),
                alt.Tooltip("valor:Q", title="Valor", format=",.2f"),
            ],
        )
        .properties(height=320)
        .interactive()
    )


def _line_roi_chart(df: pd.DataFrame) -> alt.Chart:
    monthly = (
        df.groupby("data_completa", as_index=False)
        .agg(roi_medio=("roi_desconto", "mean"))
        .sort_values("data_completa")
    )
    return (
        alt.Chart(monthly)
        .mark_line(point=True, strokeWidth=2.7, color="#1d4ed8")
        .encode(
            x=alt.X("data_completa:T", title="Mes"),
            y=alt.Y("roi_medio:Q", title="ROI medio (x)"),
            tooltip=[
                alt.Tooltip("data_completa:T", title="Mes"),
                alt.Tooltip("roi_medio:Q", title="ROI medio", format=",.3f"),
            ],
        )
        .properties(height=250)
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
            {"Metrica": "Desconto total concedido", "Valor no dashboard": _fmt_currency(current_kpis["desconto_total"])},
            {"Metrica": "Receita com desconto", "Valor no dashboard": _fmt_currency(current_kpis["receita_total"])},
            {"Metrica": "ROI ponderado", "Valor no dashboard": _fmt_roi(current_kpis["roi_ponderado"])},
            {"Metrica": "Impacto total de margem", "Valor no dashboard": _fmt_currency(current_kpis["impacto_margem_total"])},
            {"Metrica": "Taxa de aprovacao", "Valor no dashboard": _fmt_pct(current_kpis["taxa_aprovacao"])},
        ]
    )
    st.dataframe(values_df, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("SQL de referencia para homologacao")
    st.code(_build_kpi_reference_sql(start_date, end_date), language="sql")
    st.markdown("</div>", unsafe_allow_html=True)


def _render_overview_tab(df: pd.DataFrame) -> None:
    c1, c2 = st.columns([2.1, 1.2])
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Tendencia mensal: desconto total x receita com desconto")
        st.altair_chart(_line_trend_chart(df), use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Evolucao de ROI medio")
        st.altair_chart(_line_roi_chart(df), use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)

    status = (
        df.groupby("status_margem", as_index=False)
        .size()
        .rename(columns={"size": "total_registros"})
        .sort_values("total_registros", ascending=False)
    )
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Distribuicao de status de margem")
    status_chart = alt.Chart(status).mark_bar(color="#7c2d12").encode(
        x=alt.X("status_margem:N", title="Status"),
        y=alt.Y("total_registros:Q", title="Registros"),
    )
    st.altair_chart(status_chart.properties(height=220), use_container_width=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_campaign_tab(df: pd.DataFrame) -> None:
    campanhas = (
        df.groupby(["codigo_desconto", "nome_campanha", "tipo_desconto", "metodo_desconto"], as_index=False)
        .agg(
            aplicacoes=("desconto_aplicado_id", "count"),
            desconto_total=("valor_desconto_aplicado", "sum"),
            receita_total=("valor_com_desconto", "sum"),
            roi_medio=("roi_desconto", "mean"),
            impacto_margem_total=("impacto_margem", "sum"),
            taxa_aprovacao=("desconto_aprovado", "mean"),
        )
        .sort_values("desconto_total", ascending=False)
    )

    top_roi = campanhas[campanhas["aplicacoes"] >= 3].sort_values("roi_medio", ascending=False)

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top codigos por desconto concedido")
        st.altair_chart(
            _bar_chart(campanhas.head(12), "codigo_desconto", "desconto_total", "#b45309", "Codigo"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top codigos por ROI medio (min 3 aplicacoes)")
        st.altair_chart(
            _bar_chart(top_roi.head(12), "codigo_desconto", "roi_medio", "#0f766e", "Codigo"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Tabela de desempenho de campanhas")
    show = campanhas.copy()
    show["desconto_total"] = show["desconto_total"].map(_fmt_currency)
    show["receita_total"] = show["receita_total"].map(_fmt_currency)
    show["roi_medio"] = show["roi_medio"].map(_fmt_roi)
    show["impacto_margem_total"] = show["impacto_margem_total"].map(_fmt_currency)
    show["taxa_aprovacao"] = show["taxa_aprovacao"].map(_fmt_pct)
    show["aplicacoes"] = show["aplicacoes"].map(lambda x: _fmt_int(float(x)))
    show = show.rename(
        columns={
            "codigo_desconto": "Codigo desconto",
            "nome_campanha": "Campanha",
            "tipo_desconto": "Tipo",
            "metodo_desconto": "Metodo",
            "aplicacoes": "Aplicacoes",
            "desconto_total": "Desconto total",
            "receita_total": "Receita com desconto",
            "roi_medio": "ROI medio",
            "impacto_margem_total": "Impacto de margem",
            "taxa_aprovacao": "Taxa aprovacao",
        }
    )
    st.dataframe(show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_data_tab(df: pd.DataFrame) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Base consolidada")

    export_cols = [
        "data_completa",
        "codigo_desconto",
        "nome_campanha",
        "tipo_desconto",
        "metodo_desconto",
        "nivel_aplicacao",
        "regiao_pais",
        "valor_sem_desconto",
        "valor_desconto_aplicado",
        "valor_com_desconto",
        "percentual_desconto_efetivo",
        "impacto_margem",
        "status_margem",
        "desconto_aprovado",
        "roi_desconto",
    ]
    show = df[[col for col in export_cols if col in df.columns]].sort_values(
        ["data_completa", "valor_desconto_aplicado"], ascending=[False, False]
    ).copy()
    show["data_completa"] = show["data_completa"].dt.strftime("%Y-%m-%d")

    csv_data = show.to_csv(index=False).encode("utf-8")
    st.download_button(
        "Baixar CSV filtrado",
        data=csv_data,
        file_name=f"dash_descontos_filtrado_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        mime="text/csv",
    )
    st.dataframe(show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def main() -> None:
    _inject_css()
    use_snapshot = _use_snapshot_mode()
    snapshot_path = _resolve_snapshot_path("DASH_DESC_SNAPSHOT_PATH", DEFAULT_SNAPSHOT_FILE)

    st.markdown(
        """
        <div class="hero">
            <h1>Dashboard de Descontos e ROI R1</h1>
            <p>Camada de consumo certificada em <code>fact.VW_DASH_DESCONTOS_R1</code> para impacto de desconto, margem e retorno.</p>
        </div>
        """,
        unsafe_allow_html=True,
    )

    try:
        if use_snapshot:
            conn_str = ""
            metadata = _load_metadata_snapshot(snapshot_path)
        else:
            conn_str = _build_conn_str()
            metadata = _load_metadata(conn_str)
    except Exception as exc:  # noqa: BLE001
        if use_snapshot:
            st.error("Nao foi possivel inicializar o dashboard de descontos em modo snapshot.")
            st.code(str(exc))
            st.write("- Confirme se o arquivo de snapshot existe e tem dados validos.")
            st.write(f"- Caminho esperado: `{snapshot_path}`")
            st.write("- Gere novamente com `python scripts/snapshots/export_dash_snapshots.py`.")
            st.stop()

        st.error("Nao foi possivel inicializar o dashboard de descontos em modo SQL.")
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

        selected_regioes = tuple(st.multiselect("Regiao", metadata["regioes"]))
        selected_tipos = tuple(st.multiselect("Tipo de desconto", metadata["tipos_desconto"]))
        selected_metodos = tuple(st.multiselect("Metodo de desconto", metadata["metodos_desconto"]))
        selected_codigos = tuple(st.multiselect("Codigo de desconto", metadata["codigos_desconto"]))
        selected_niveis = tuple(st.multiselect("Nivel de aplicacao", metadata["niveis_aplicacao"]))
        compare_previous = st.toggle("Comparar com periodo anterior", value=True)

        if st.button("Atualizar dados", use_container_width=True):
            st.cache_data.clear()
            st.rerun()

        if use_snapshot:
            st.info("Fonte de dados: snapshot local")
            generated_at = _snapshot_generated_at(snapshot_path)
            if generated_at:
                st.caption(f"Snapshot atualizado em: {generated_at}")
            st.caption(f"Arquivo: {snapshot_path}")
        else:
            st.info("Fonte de dados: SQL Server DW")

    spinner_text = "Carregando snapshot de descontos..." if use_snapshot else "Consultando descontos no DW..."
    with st.spinner(spinner_text):
        try:
            if use_snapshot:
                df = _load_discount_data_snapshot(
                    snapshot_path=snapshot_path,
                    start_date=start_date,
                    end_date=end_date,
                    regioes=selected_regioes,
                    tipos_desconto=selected_tipos,
                    metodos_desconto=selected_metodos,
                    codigos_desconto=selected_codigos,
                    niveis_aplicacao=selected_niveis,
                )
            else:
                df = _load_discount_data(
                    conn_str=conn_str,
                    start_date=start_date,
                    end_date=end_date,
                    regioes=selected_regioes,
                    tipos_desconto=selected_tipos,
                    metodos_desconto=selected_metodos,
                    codigos_desconto=selected_codigos,
                    niveis_aplicacao=selected_niveis,
                )
        except Exception as exc:  # noqa: BLE001
            if use_snapshot:
                st.error("Falha ao carregar os dados de snapshot de descontos.")
                st.code(str(exc))
                st.write(f"- Caminho do snapshot: `{snapshot_path}`")
                st.stop()

            st.error("Falha ao consultar os dados da view de descontos.")
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
        if use_snapshot:
            prev_df = _load_discount_data_snapshot(
                snapshot_path=snapshot_path,
                start_date=prev_start,
                end_date=prev_end,
                regioes=selected_regioes,
                tipos_desconto=selected_tipos,
                metodos_desconto=selected_metodos,
                codigos_desconto=selected_codigos,
                niveis_aplicacao=selected_niveis,
            )
        else:
            prev_df = _load_discount_data(
                conn_str=conn_str,
                start_date=prev_start,
                end_date=prev_end,
                regioes=selected_regioes,
                tipos_desconto=selected_tipos,
                metodos_desconto=selected_metodos,
                codigos_desconto=selected_codigos,
                niveis_aplicacao=selected_niveis,
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

    tab_overview, tab_campaign, tab_metrics, tab_data = st.tabs(
        ["Visao geral", "Campanhas", "Metricas (PRD)", "Base detalhada"]
    )

    with tab_overview:
        _render_overview_tab(df)

    with tab_campaign:
        _render_campaign_tab(df)

    with tab_metrics:
        _render_metric_dictionary_tab(current_kpis, start_date, end_date)

    with tab_data:
        _render_data_tab(df)


if __name__ == "__main__":
    main()
