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


VIEW_NAME = "fact.VW_DASH_VENDAS_R1"

NUMERIC_COLUMNS = [
    "quantidade_vendida",
    "valor_total_bruto",
    "valor_total_descontos",
    "valor_total_liquido",
    "margem_bruta",
    "quantidade_devolvida",
    "valor_devolvido",
    "valor_comissao",
]

TEXT_COLUMNS_DEFAULTS: dict[str, str] = {
    "categoria": "Nao informado",
    "subcategoria": "Nao informado",
    "marca": "Nao informado",
    "nome_produto": "Nao informado",
    "estado": "Nao informado",
    "regiao_pais": "Nao informado",
    "cidade": "Nao informado",
    "nome_vendedor": "Sem vendedor",
    "nome_equipe": "Sem equipe",
}

KPI_CATALOG: list[dict[str, str]] = [
    {
        "kpi": "Receita liquida",
        "formula_prd": "SUM(valor_total_liquido)",
        "fonte": "fact.VW_DASH_VENDAS_R1.valor_total_liquido",
        "status_prd": "Atendido (PRD 11.1)",
    },
    {
        "kpi": "Margem bruta",
        "formula_prd": "SUM(valor_total_liquido - custo_total)",
        "fonte": "fact.VW_DASH_VENDAS_R1.margem_bruta",
        "status_prd": "Atendido (PRD 11.1)",
    },
    {
        "kpi": "Taxa de devolucao",
        "formula_prd": "SUM(quantidade_devolvida) / SUM(quantidade_vendida)",
        "fonte": "fact.VW_DASH_VENDAS_R1.quantidade_devolvida, quantidade_vendida",
        "status_prd": "Atendido (PRD 11.1)",
    },
    {
        "kpi": "Ticket medio",
        "formula_prd": "SUM(valor_total_liquido) / COUNT(DISTINCT numero_pedido)",
        "fonte": "fact.VW_DASH_VENDAS_R1.valor_total_liquido, numero_pedido",
        "status_prd": "Extra (playbook R1)",
    },
    {
        "kpi": "Desconto medio",
        "formula_prd": "SUM(valor_total_descontos) / SUM(valor_total_bruto)",
        "fonte": "fact.VW_DASH_VENDAS_R1.valor_total_descontos, valor_total_bruto",
        "status_prd": "Extra (monitor de margem)",
    },
]


st.set_page_config(
    page_title="Dashboard de Vendas R1",
    page_icon=":chart_with_upwards_trend:",
    layout="wide",
)


def _inject_css() -> None:
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;700;800&family=JetBrains+Mono:wght@500&display=swap');

        :root {
            --card-bg: rgba(255, 255, 255, 0.82);
            --card-border: rgba(82, 109, 130, 0.20);
            --accent: #0f766e;
            --accent-2: #c2410c;
            --text-main: #102a43;
            --text-soft: #486581;
        }

        .stApp {
            background:
                radial-gradient(circle at 4% 0%, rgba(186, 230, 253, 0.45), transparent 42%),
                radial-gradient(circle at 94% 16%, rgba(253, 230, 138, 0.38), transparent 36%),
                linear-gradient(165deg, #f7fdfc 0%, #eff8ff 100%);
            color: var(--text-main);
            font-family: 'Manrope', sans-serif;
        }

        .block-container {
            padding-top: 1.1rem !important;
            padding-bottom: 1.4rem !important;
            max-width: 1480px;
        }

        .hero {
            border-radius: 18px;
            padding: 1rem 1.2rem;
            border: 1px solid var(--card-border);
            background: linear-gradient(120deg, rgba(255, 255, 255, 0.96) 0%, rgba(240, 249, 255, 0.92) 100%);
            box-shadow: 0 12px 24px rgba(15, 23, 42, 0.06);
            margin-bottom: 0.75rem;
            animation: fadeIn 420ms ease-out both;
        }

        .hero h1 {
            margin: 0 0 0.28rem 0;
            font-size: 1.45rem;
            line-height: 1.2;
            font-weight: 800;
            letter-spacing: -0.01em;
            color: #0b3a53;
        }

        .hero p {
            margin: 0;
            color: var(--text-soft);
            font-size: 0.94rem;
            font-weight: 500;
        }

        .card {
            border-radius: 16px;
            padding: 0.65rem 0.85rem 0.35rem 0.85rem;
            border: 1px solid var(--card-border);
            background: var(--card-bg);
            box-shadow: 0 8px 18px rgba(15, 23, 42, 0.05);
            margin-bottom: 0.8rem;
            animation: fadeIn 420ms ease-out both;
        }

        [data-testid="stMetricValue"] {
            font-family: 'JetBrains Mono', monospace;
            letter-spacing: -0.02em;
        }

        [data-testid="stMetricLabel"] p {
            font-weight: 700;
            color: #334e68;
        }

        .insight {
            border-left: 5px solid var(--accent);
            border-radius: 12px;
            padding: 0.7rem 0.85rem;
            background: rgba(255, 255, 255, 0.72);
            margin-bottom: 0.55rem;
            box-shadow: 0 6px 14px rgba(15, 23, 42, 0.04);
        }

        .insight.warning {
            border-left-color: var(--accent-2);
        }

        .insight b {
            color: #0b3a53;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(4px); }
            to { opacity: 1; transform: translateY(0); }
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


def _resolve_sql_driver() -> str:
    explicit_driver = os.getenv("DASH_SQL_DRIVER")
    if explicit_driver:
        return explicit_driver

    installed = []
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
    driver = _resolve_sql_driver()
    server = os.getenv("DASH_SQL_SERVER", "sqlserver")
    port = os.getenv("DASH_SQL_PORT", "").strip()
    database = os.getenv("DASH_DW_DB", "DW_ECOMMERCE")
    user = os.getenv("DASH_SQL_USER", "bi_reader")
    password = os.getenv("DASH_SQL_PASSWORD", "")
    encrypt = os.getenv("DASH_SQL_ENCRYPT", "yes")
    trust_server_certificate = os.getenv("DASH_SQL_TRUST_SERVER_CERTIFICATE", "yes")

    if not password:
        raise ValueError("Variavel `DASH_SQL_PASSWORD` nao definida para o dashboard.")

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
            "Dependencia ausente: pyodbc. Instale com `pip install -r python/dashboards/vendas/requirements.txt`."
        )
    timeout = _safe_int(os.getenv("DASH_SQL_TIMEOUT_SECONDS"), 120)
    connection = pyodbc.connect(conn_str, autocommit=True)
    connection.timeout = timeout
    return connection


def _suggest_connection_fix(error_text: str) -> list[str]:
    upper = error_text.upper()
    suggestions: list[str] = []

    if "IM002" in upper:
        suggestions.append("Driver ODBC nao encontrado. Ajuste `DASH_SQL_DRIVER` para ODBC 17/18.")
    if "08001" in upper or "SERVER DOES NOT EXIST" in upper:
        suggestions.append("Falha de conexao no servidor. Revise `DASH_SQL_SERVER` e `DASH_SQL_PORT`.")
    if "28000" in upper or "LOGIN FAILED" in upper:
        suggestions.append("Falha de autenticacao. Revise `DASH_SQL_USER` e `DASH_SQL_PASSWORD`.")
    if "INVALID OBJECT NAME" in upper and "VW_DASH_VENDAS_R1" in upper:
        suggestions.append("View de consumo ausente. Execute `sql/dw/04_views/12_vw_dash_vendas_r1.sql`.")
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
            raise ValueError("A view de vendas nao retornou datas validas.")

        min_data = pd.to_datetime(bounds.loc[0, "min_data"]).date()
        max_data = pd.to_datetime(bounds.loc[0, "max_data"]).date()

        states = pd.read_sql(
            f"SELECT DISTINCT estado FROM {VIEW_NAME} WHERE estado IS NOT NULL ORDER BY estado;",
            connection,
        )["estado"].astype(str).tolist()
        regions = pd.read_sql(
            f"SELECT DISTINCT regiao_pais FROM {VIEW_NAME} WHERE regiao_pais IS NOT NULL ORDER BY regiao_pais;",
            connection,
        )["regiao_pais"].astype(str).tolist()
        categories = pd.read_sql(
            f"SELECT DISTINCT categoria FROM {VIEW_NAME} WHERE categoria IS NOT NULL ORDER BY categoria;",
            connection,
        )["categoria"].astype(str).tolist()
        sellers = pd.read_sql(
            f"SELECT DISTINCT nome_vendedor FROM {VIEW_NAME} WHERE nome_vendedor IS NOT NULL ORDER BY nome_vendedor;",
            connection,
        )["nome_vendedor"].astype(str).tolist()
        teams = pd.read_sql(
            f"SELECT DISTINCT nome_equipe FROM {VIEW_NAME} WHERE nome_equipe IS NOT NULL ORDER BY nome_equipe;",
            connection,
        )["nome_equipe"].astype(str).tolist()

        return {
            "min_data": min_data,
            "max_data": max_data,
            "estados": states,
            "regioes": regions,
            "categorias": categories,
            "vendedores": sellers,
            "equipes": teams,
        }
    finally:
        connection.close()


@st.cache_data(ttl=180, show_spinner=False)
def _load_sales_data(
    conn_str: str,
    start_date: date,
    end_date: date,
    estados: tuple[str, ...],
    regioes: tuple[str, ...],
    categorias: tuple[str, ...],
    vendedores: tuple[str, ...],
    equipes: tuple[str, ...],
) -> pd.DataFrame:
    params: list[Any] = [start_date, end_date]
    where = "WHERE CAST(data_completa AS date) BETWEEN ? AND ?"
    where += _build_in_filter("estado", estados, params)
    where += _build_in_filter("regiao_pais", regioes, params)
    where += _build_in_filter("categoria", categorias, params)
    where += _build_in_filter("nome_vendedor", vendedores, params)
    where += _build_in_filter("nome_equipe", equipes, params)

    query = f"""
    SELECT
        CAST(data_completa AS date) AS data_completa,
        ano,
        trimestre,
        mes,
        nome_mes,
        estado,
        cidade,
        regiao_pais,
        categoria,
        subcategoria,
        marca,
        nome_produto,
        COALESCE(nome_vendedor, 'Sem vendedor') AS nome_vendedor,
        COALESCE(nome_equipe, 'Sem equipe') AS nome_equipe,
        numero_pedido,
        venda_original_id,
        quantidade_vendida,
        valor_total_bruto,
        valor_total_descontos,
        valor_total_liquido,
        margem_bruta,
        quantidade_devolvida,
        valor_devolvido,
        valor_comissao,
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

    if "data_completa" not in df.columns:
        raise ValueError("Coluna `data_completa` nao encontrada na view de consumo.")
    df["data_completa"] = pd.to_datetime(df["data_completa"], errors="coerce")
    df = df.dropna(subset=["data_completa"]).copy()

    if "data_atualizacao" in df.columns:
        df["data_atualizacao"] = pd.to_datetime(df["data_atualizacao"], errors="coerce")

    return df


def _fmt_currency(value: float) -> str:
    masked = f"{value:,.2f}"
    return "R$ " + masked.replace(",", "X").replace(".", ",").replace("X", ".")


def _fmt_int(value: float) -> str:
    masked = f"{int(round(value)):,.0f}"
    return masked.replace(",", ".")


def _fmt_pct(value: float) -> str:
    return f"{value * 100:.1f}%".replace(".", ",")


def _compute_kpis(df: pd.DataFrame) -> dict[str, float]:
    receita = _safe_float(df["valor_total_liquido"].sum())
    margem = _safe_float(df["margem_bruta"].sum())
    itens = _safe_float(df["quantidade_vendida"].sum())
    qtd_devolvida = _safe_float(df["quantidade_devolvida"].sum())
    descontos = _safe_float(df["valor_total_descontos"].sum())
    bruto = _safe_float(df["valor_total_bruto"].sum())
    comissao = _safe_float(df["valor_comissao"].sum())

    pedidos_col = "numero_pedido" if "numero_pedido" in df.columns else "venda_original_id"
    pedidos = float(df[pedidos_col].nunique()) if pedidos_col in df.columns else 0.0

    return {
        "receita": receita,
        "margem": margem,
        "margem_pct": (margem / receita) if receita > 0 else 0.0,
        "itens": itens,
        "pedidos": pedidos,
        "ticket_medio": (receita / pedidos) if pedidos > 0 else 0.0,
        "taxa_devolucao": (qtd_devolvida / itens) if itens > 0 else 0.0,
        "desconto_pct": (descontos / bruto) if bruto > 0 else 0.0,
        "comissao": comissao,
    }


def _resolve_local_now() -> tuple[datetime, str]:
    timezone_name = os.getenv("DASH_TIMEZONE", "America/Sao_Paulo")
    try:
        timezone_obj = ZoneInfo(timezone_name)
    except Exception:  # noqa: BLE001
        timezone_obj = ZoneInfo("UTC")
        timezone_name = "UTC"
    now_local = datetime.now(tz=timezone_obj)
    return now_local, timezone_name


def _evaluate_freshness_status(last_data_date: date) -> dict[str, str]:
    now_local, timezone_name = _resolve_local_now()

    # Regra de produto (RNF-02): dados do dia D disponiveis ate D+1 08:00.
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
    SUM(valor_total_liquido) AS receita_liquida,
    SUM(margem_bruta) AS margem_bruta,
    SUM(CASE WHEN quantidade_vendida > 0 THEN quantidade_devolvida ELSE 0 END) * 1.0
        / NULLIF(SUM(quantidade_vendida), 0) AS taxa_devolucao,
    SUM(valor_total_liquido) * 1.0
        / NULLIF(COUNT(DISTINCT numero_pedido), 0) AS ticket_medio
FROM fact.VW_DASH_VENDAS_R1
WHERE CAST(data_completa AS date) BETWEEN '{start_date.isoformat()}' AND '{end_date.isoformat()}';
""".strip()


def _render_metric_dictionary_tab(
    current_kpis: dict[str, float],
    start_date: date,
    end_date: date,
) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Dicionario de metricas (RF-13)")
    catalog_df = pd.DataFrame(KPI_CATALOG)
    catalog_df = catalog_df.rename(
        columns={
            "kpi": "Metrica",
            "formula_prd": "Formula oficial",
            "fonte": "Fonte de dados",
            "status_prd": "Status",
        }
    )
    st.dataframe(catalog_df, use_container_width=True, hide_index=True)
    st.caption("Escopo consolidado neste dashboard: vendas e margem. Metas/ROI ficam para os proximos dashboards R1.")
    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Valores do periodo selecionado")
    values_df = pd.DataFrame(
        [
            {"Metrica": "Receita liquida", "Valor no dashboard": _fmt_currency(current_kpis["receita"])},
            {"Metrica": "Margem bruta", "Valor no dashboard": _fmt_currency(current_kpis["margem"])},
            {"Metrica": "Taxa de devolucao", "Valor no dashboard": _fmt_pct(current_kpis["taxa_devolucao"])},
            {"Metrica": "Ticket medio", "Valor no dashboard": _fmt_currency(current_kpis["ticket_medio"])},
            {"Metrica": "Desconto medio", "Valor no dashboard": _fmt_pct(current_kpis["desconto_pct"])},
        ]
    )
    st.dataframe(values_df, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("SQL de referencia para homologacao")
    st.code(_build_kpi_reference_sql(start_date, end_date), language="sql")
    st.markdown("</div>", unsafe_allow_html=True)


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


def _render_kpi_strip(
    current: dict[str, float],
    previous: dict[str, float] | None,
) -> None:
    labels = [
        ("Receita liquida", "receita", _fmt_currency, "normal"),
        ("Margem bruta", "margem", _fmt_currency, "normal"),
        ("Margem %", "margem_pct", _fmt_pct, "normal"),
        ("Ticket medio", "ticket_medio", _fmt_currency, "normal"),
        ("Itens vendidos", "itens", _fmt_int, "normal"),
        ("Taxa devolucao", "taxa_devolucao", _fmt_pct, "inverse"),
        ("Desconto medio", "desconto_pct", _fmt_pct, "inverse"),
        ("Comissao total", "comissao", _fmt_currency, "normal"),
    ]

    metric_cols = st.columns(4)
    for idx, (label, key, formatter, delta_color) in enumerate(labels):
        target = metric_cols[idx % 4]
        with target:
            delta = None
            if previous is not None and key in previous:
                delta = _fmt_delta(current[key], previous[key])
            st.metric(
                label=label,
                value=formatter(current[key]),
                delta=delta,
                delta_color=delta_color,
            )


def _line_trend_chart(df: pd.DataFrame, granularity: str) -> alt.Chart:
    freq = "MS" if granularity == "Mes" else "D"

    grouped = (
        df.set_index("data_completa")
        .resample(freq)
        .agg(
            receita=("valor_total_liquido", "sum"),
            margem=("margem_bruta", "sum"),
            pedidos=("numero_pedido", "nunique"),
        )
        .reset_index()
    )

    melted = grouped.melt(
        id_vars=["data_completa"],
        value_vars=["receita", "margem"],
        var_name="indicador",
        value_name="valor",
    )

    return (
        alt.Chart(melted)
        .mark_line(point=True, strokeWidth=2.7)
        .encode(
            x=alt.X("data_completa:T", title="Data"),
            y=alt.Y("valor:Q", title="Valor"),
            color=alt.Color(
                "indicador:N",
                scale=alt.Scale(
                    domain=["receita", "margem"],
                    range=["#0f766e", "#c2410c"],
                ),
                legend=alt.Legend(title="Serie"),
            ),
            tooltip=[
                alt.Tooltip("data_completa:T", title="Data"),
                alt.Tooltip("indicador:N", title="Indicador"),
                alt.Tooltip("valor:Q", title="Valor", format=",.2f"),
            ],
        )
        .properties(height=330)
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
        .properties(height=330)
    )


def _render_insights(df: pd.DataFrame) -> None:
    receita_por_categoria = (
        df.groupby("categoria", as_index=False)["valor_total_liquido"].sum().sort_values("valor_total_liquido", ascending=False)
    )
    receita_por_estado = (
        df.groupby("estado", as_index=False)["valor_total_liquido"].sum().sort_values("valor_total_liquido", ascending=False)
    )
    diario = df.groupby(df["data_completa"].dt.date, as_index=False)["valor_total_liquido"].sum().sort_values("valor_total_liquido", ascending=False)

    if receita_por_categoria.empty or receita_por_estado.empty or diario.empty:
        st.info("Sem dados suficientes para gerar insights.")
        return

    top_categoria = receita_por_categoria.iloc[0]
    top_estado = receita_por_estado.iloc[0]
    melhor_dia = diario.iloc[0]

    st.markdown(
        (
            f"<div class='insight'><b>Categoria lider:</b> {top_categoria['categoria']} "
            f"com {_fmt_currency(_safe_float(top_categoria['valor_total_liquido']))} de receita.</div>"
        ),
        unsafe_allow_html=True,
    )
    st.markdown(
        (
            f"<div class='insight'><b>Estado lider:</b> {top_estado['estado']} "
            f"com {_fmt_currency(_safe_float(top_estado['valor_total_liquido']))} de receita.</div>"
        ),
        unsafe_allow_html=True,
    )
    st.markdown(
        (
            f"<div class='insight warning'><b>Maior dia de faturamento:</b> "
            f"{pd.to_datetime(melhor_dia['data_completa']).strftime('%d/%m/%Y')} "
            f"({_fmt_currency(_safe_float(melhor_dia['valor_total_liquido']))}).</div>"
        ),
        unsafe_allow_html=True,
    )


def _render_overview_tab(df: pd.DataFrame, granularity: str) -> None:
    c1, c2 = st.columns([2.3, 1.2])
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader(f"Tendencia de receita e margem ({granularity.lower()})")
        st.altair_chart(_line_trend_chart(df, granularity), use_container_width=True)
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Leituras rapidas")
        _render_insights(df)
        st.markdown("</div>", unsafe_allow_html=True)

    weekday_order = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    weekday = df.copy()
    weekday["weekday"] = weekday["data_completa"].dt.strftime("%a")
    weekday = (
        weekday.groupby("weekday", as_index=False)["valor_total_liquido"]
        .sum()
        .set_index("weekday")
        .reindex(weekday_order)
        .fillna(0.0)
        .reset_index()
    )
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Receita por dia da semana")
    weekday_chart = alt.Chart(weekday).mark_bar(color="#0b7285").encode(
        x=alt.X("weekday:N", title="Dia"),
        y=alt.Y("valor_total_liquido:Q", title="Receita"),
        tooltip=[alt.Tooltip("weekday:N", title="Dia"), alt.Tooltip("valor_total_liquido:Q", title="Receita", format=",.2f")],
    )
    st.altair_chart(weekday_chart.properties(height=230), use_container_width=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_product_region_tab(df: pd.DataFrame) -> None:
    top_produtos = (
        df.groupby("nome_produto", as_index=False)["valor_total_liquido"]
        .sum()
        .sort_values("valor_total_liquido", ascending=False)
        .head(12)
    )
    top_estados = (
        df.groupby("estado", as_index=False)["valor_total_liquido"]
        .sum()
        .sort_values("valor_total_liquido", ascending=False)
        .head(12)
    )
    mix_categoria = (
        df.groupby("categoria", as_index=False)
        .agg(
            receita=("valor_total_liquido", "sum"),
            margem=("margem_bruta", "sum"),
            itens=("quantidade_vendida", "sum"),
            descontos=("valor_total_descontos", "sum"),
        )
        .sort_values("receita", ascending=False)
    )
    mix_categoria["margem_pct"] = mix_categoria.apply(
        lambda row: (row["margem"] / row["receita"]) if row["receita"] else 0.0, axis=1
    )
    mix_categoria["desconto_pct"] = mix_categoria.apply(
        lambda row: (row["descontos"] / row["receita"]) if row["receita"] else 0.0, axis=1
    )

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top produtos por receita")
        st.altair_chart(
            _bar_chart(top_produtos, "nome_produto", "valor_total_liquido", "#0f766e", "Produto"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Top estados por receita")
        st.altair_chart(
            _bar_chart(top_estados, "estado", "valor_total_liquido", "#1d4ed8", "Estado"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Mix de categorias")
    mix_show = mix_categoria.copy()
    mix_show["receita"] = mix_show["receita"].map(_fmt_currency)
    mix_show["margem"] = mix_show["margem"].map(_fmt_currency)
    mix_show["itens"] = mix_show["itens"].map(_fmt_int)
    mix_show["margem_pct"] = mix_show["margem_pct"].map(_fmt_pct)
    mix_show["desconto_pct"] = mix_show["desconto_pct"].map(_fmt_pct)
    mix_show = mix_show.rename(
        columns={
            "categoria": "Categoria",
            "receita": "Receita",
            "margem": "Margem",
            "itens": "Itens",
            "margem_pct": "Margem %",
            "desconto_pct": "Desconto %",
        }
    )
    st.dataframe(mix_show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_sales_tab(df: pd.DataFrame) -> None:
    ranking = (
        df.groupby(["nome_vendedor", "nome_equipe"], as_index=False)
        .agg(
            receita=("valor_total_liquido", "sum"),
            margem=("margem_bruta", "sum"),
            pedidos=("numero_pedido", "nunique"),
            itens=("quantidade_vendida", "sum"),
        )
        .sort_values("receita", ascending=False)
    )
    ranking["margem_pct"] = ranking.apply(lambda row: row["margem"] / row["receita"] if row["receita"] else 0.0, axis=1)

    top_vendedores = ranking.head(12)
    top_equipes = (
        df.groupby("nome_equipe", as_index=False)["valor_total_liquido"]
        .sum()
        .sort_values("valor_total_liquido", ascending=False)
        .head(10)
    )

    c1, c2 = st.columns(2)
    with c1:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Ranking de vendedores")
        st.altair_chart(
            _bar_chart(top_vendedores, "nome_vendedor", "receita", "#b45309", "Vendedor"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.subheader("Receita por equipe")
        st.altair_chart(
            _bar_chart(top_equipes, "nome_equipe", "valor_total_liquido", "#0f766e", "Equipe"),
            use_container_width=True,
        )
        st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Tabela detalhada de performance comercial")
    show = ranking.copy()
    show["receita"] = show["receita"].map(_fmt_currency)
    show["margem"] = show["margem"].map(_fmt_currency)
    show["margem_pct"] = show["margem_pct"].map(_fmt_pct)
    show["pedidos"] = show["pedidos"].map(_fmt_int)
    show["itens"] = show["itens"].map(_fmt_int)
    show = show.rename(
        columns={
            "nome_vendedor": "Vendedor",
            "nome_equipe": "Equipe",
            "receita": "Receita",
            "margem": "Margem",
            "margem_pct": "Margem %",
            "pedidos": "Pedidos",
            "itens": "Itens",
        }
    )
    st.dataframe(show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def _render_data_tab(df: pd.DataFrame) -> None:
    st.markdown("<div class='card'>", unsafe_allow_html=True)
    st.subheader("Base consolidada")
    st.caption(f"Registros retornados: {_fmt_int(float(len(df)))}")

    export_cols = [
        "data_completa",
        "estado",
        "regiao_pais",
        "categoria",
        "subcategoria",
        "nome_produto",
        "nome_vendedor",
        "nome_equipe",
        "numero_pedido",
        "quantidade_vendida",
        "valor_total_bruto",
        "valor_total_descontos",
        "valor_total_liquido",
        "margem_bruta",
        "valor_comissao",
    ]
    export_cols = [col for col in export_cols if col in df.columns]
    show = df[export_cols].sort_values("data_completa", ascending=False).copy()
    show["data_completa"] = show["data_completa"].dt.strftime("%Y-%m-%d")

    csv_data = show.to_csv(index=False).encode("utf-8")
    st.download_button(
        "Baixar CSV filtrado",
        data=csv_data,
        file_name=f"dash_vendas_filtrado_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        mime="text/csv",
        use_container_width=False,
    )
    st.dataframe(show, use_container_width=True, hide_index=True)
    st.markdown("</div>", unsafe_allow_html=True)


def main() -> None:
    _inject_css()

    st.markdown(
        """
        <div class="hero">
            <h1>Dashboard de Vendas R1</h1>
            <p>Camada de consumo certificada em <code>fact.VW_DASH_VENDAS_R1</code> com filtros de negocio e leitura rapida de performance.</p>
        </div>
        """,
        unsafe_allow_html=True,
    )

    try:
        conn_str = _build_conn_str()
        metadata = _load_metadata(conn_str)
    except Exception as exc:  # noqa: BLE001
        st.error("Nao foi possivel inicializar o dashboard.")
        st.code(str(exc))
        for suggestion in _suggest_connection_fix(str(exc)):
            st.write(f"- {suggestion}")
        st.stop()

    min_data = metadata["min_data"]
    max_data = metadata["max_data"]
    default_start = max(min_data, max_data - timedelta(days=89))

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

        selected_estados = tuple(st.multiselect("Estado", metadata["estados"]))
        selected_regioes = tuple(st.multiselect("Regiao", metadata["regioes"]))
        selected_categorias = tuple(st.multiselect("Categoria", metadata["categorias"]))
        selected_equipes = tuple(st.multiselect("Equipe", metadata["equipes"]))
        selected_vendedores = tuple(st.multiselect("Vendedor", metadata["vendedores"]))
        trend_granularity = st.selectbox("Granularidade da tendencia", ["Mes", "Dia"], index=0)
        compare_previous = st.toggle("Comparar com periodo anterior", value=True)

        if st.button("Atualizar dados", use_container_width=True):
            st.cache_data.clear()
            st.rerun()

        st.caption(
            f"Base disponivel: {min_data.isoformat()} ate {max_data.isoformat()}."
        )

    with st.spinner("Consultando vendas no DW..."):
        try:
            df = _load_sales_data(
                conn_str=conn_str,
                start_date=start_date,
                end_date=end_date,
                estados=selected_estados,
                regioes=selected_regioes,
                categorias=selected_categorias,
                vendedores=selected_vendedores,
                equipes=selected_equipes,
            )
        except Exception as exc:  # noqa: BLE001
            st.error("Falha ao consultar os dados da view de vendas.")
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
        prev_df = _load_sales_data(
            conn_str=conn_str,
            start_date=prev_start,
            end_date=prev_end,
            estados=selected_estados,
            regioes=selected_regioes,
            categorias=selected_categorias,
            vendedores=selected_vendedores,
            equipes=selected_equipes,
        )
        if not prev_df.empty:
            previous_kpis = _compute_kpis(prev_df)

    current_kpis = _compute_kpis(df)
    freshness = _evaluate_freshness_status(max_data)

    period_label = f"Periodo ativo: {start_date.isoformat()} a {end_date.isoformat()}"
    updated_at = None
    if "data_atualizacao" in df.columns:
        updated_at = df["data_atualizacao"].max()

    c_period, c_update, c_sla = st.columns([2.1, 1.2, 1.7])
    with c_period:
        st.caption(period_label)
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

    tab_overview, tab_produtos, tab_comercial, tab_metricas, tab_base = st.tabs(
        ["Visao geral", "Produtos e regioes", "Comercial", "Metricas (PRD)", "Base detalhada"]
    )

    with tab_overview:
        _render_overview_tab(df, trend_granularity)

    with tab_produtos:
        _render_product_region_tab(df)

    with tab_comercial:
        _render_sales_tab(df)

    with tab_metricas:
        _render_metric_dictionary_tab(current_kpis, start_date, end_date)

    with tab_base:
        _render_data_tab(df)


if __name__ == "__main__":
    main()
