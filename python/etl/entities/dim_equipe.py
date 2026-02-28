from __future__ import annotations

import re
from datetime import date, datetime
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_equipe"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_equipe.sql").format(batch_size=safe_batch_size)
    return query_all(
        oltp_connection,
        sql,
        (
            cutoff_updated_at,
            watermark_updated_at,
            watermark_updated_at,
            int(watermark_id),
        ),
    )


def transform_rows(raw_rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    transformed_rows: list[dict[str, Any]] = []
    soft_deleted_count = 0

    for raw in raw_rows:
        team_id = int(raw["team_id"])
        deleted_at = raw.get("deleted_at")
        if deleted_at is not None:
            soft_deleted_count += 1

        data_criacao = _to_date(raw.get("created_at")) or date(1900, 1, 1)
        data_ultima_atualizacao = _to_datetime(raw.get("updated_at"), fallback=raw.get("created_at"))
        situacao = _resolve_situacao(raw.get("is_active"), deleted_at)
        eh_ativa = 1 if situacao == "Ativa" else 0

        qtd_membros_atual = _to_int(raw.get("active_sellers_count"), default=0, min_value=0)
        qtd_membros_total = _to_int(raw.get("total_sellers_count"), default=0, min_value=0)
        qtd_membros_ideal = max(qtd_membros_atual, qtd_membros_total, 5)

        meta_mensal = _to_decimal(raw.get("monthly_goal_sum"), default=0.0)
        meta_trimestral = None if meta_mensal is None else round(meta_mensal * 3.0, 2)
        meta_anual = None if meta_mensal is None else round(meta_mensal * 12.0, 2)
        qtd_meta_vendas_mes = None if meta_mensal is None else max(1, int(round(meta_mensal / 50000.0)))

        nome_equipe = _clean_text(raw.get("team_name"), default=f"Equipe {team_id}", max_len=100)
        codigo_equipe = _clean_text(raw.get("team_code"), default=f"TEAM-{team_id:03d}", max_len=20)
        tipo_equipe = _clean_text(raw.get("team_type"), default=None, max_len=30)
        categoria_equipe = _clean_text(raw.get("team_category"), default=None, max_len=30)
        regional = _clean_text(raw.get("region_name"), default=None, max_len=50)
        estado_sede = _normalize_state(raw.get("region_state"))
        cidade_sede = _clean_text(raw.get("region_city"), default=None, max_len=100)
        nome_lider = _clean_text(raw.get("leader_name"), default=None, max_len=100)

        transformed = {
            "equipe_original_id": team_id,
            "nome_equipe": nome_equipe,
            "codigo_equipe": codigo_equipe,
            "tipo_equipe": tipo_equipe,
            "categoria_equipe": categoria_equipe,
            "regional": regional,
            "estado_sede": estado_sede,
            "cidade_sede": cidade_sede,
            # lider_equipe_id referencia surrogate key da DIM_VENDEDOR.
            # Mantemos nulo ate resolver o mapeamento de chave natural -> surrogate.
            "lider_equipe_id": None,
            "nome_lider": nome_lider,
            "email_lider": None,
            "meta_mensal_equipe": meta_mensal,
            "meta_trimestral_equipe": meta_trimestral,
            "meta_anual_equipe": meta_anual,
            "qtd_meta_vendas_mes": qtd_meta_vendas_mes,
            "qtd_membros_atual": qtd_membros_atual,
            "qtd_membros_ideal": qtd_membros_ideal,
            "total_vendas_mes_anterior": None,
            "percentual_meta_mes_anterior": None,
            "ranking_ultimo_mes": None,
            "data_criacao": data_criacao,
            "data_ultima_atualizacao": data_ultima_atualizacao,
            "data_inativacao": _to_date(deleted_at) if deleted_at is not None else None,
            "situacao": situacao,
            "eh_ativa": eh_ativa,
            "observacoes": _build_notes(tipo_equipe, categoria_equipe, qtd_membros_atual, qtd_membros_total),
            "source_updated_at": data_ultima_atualizacao,
            "source_id": team_id,
        }
        transformed_rows.append(transformed)

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_equipe.sql")
    params = [_to_upsert_params(row) for row in rows]
    cursor = dw_connection.cursor()
    try:
        try:
            cursor.fast_executemany = True
        except Exception:  # noqa: BLE001
            pass
        cursor.executemany(sql, params)
    finally:
        cursor.close()
    return len(rows)


def get_batch_watermark(rows: list[dict[str, Any]]) -> tuple[datetime, int]:
    if not rows:
        raise ValueError("Nao e possivel calcular watermark de lote vazio.")
    last_row = rows[-1]
    return last_row["source_updated_at"], int(last_row["source_id"])


def _to_upsert_params(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        row["equipe_original_id"],
        row["nome_equipe"],
        row["codigo_equipe"],
        row["tipo_equipe"],
        row["categoria_equipe"],
        row["regional"],
        row["estado_sede"],
        row["cidade_sede"],
        row["lider_equipe_id"],
        row["nome_lider"],
        row["email_lider"],
        row["meta_mensal_equipe"],
        row["meta_trimestral_equipe"],
        row["meta_anual_equipe"],
        row["qtd_meta_vendas_mes"],
        row["qtd_membros_atual"],
        row["qtd_membros_ideal"],
        row["total_vendas_mes_anterior"],
        row["percentual_meta_mes_anterior"],
        row["ranking_ultimo_mes"],
        row["data_criacao"],
        row["data_ultima_atualizacao"],
        row["data_inativacao"],
        row["situacao"],
        row["eh_ativa"],
        row["observacoes"],
    )


def _clean_text(value: Any, *, default: str | None, max_len: int | None) -> str | None:
    if value is None:
        return default
    text = str(value).strip()
    if not text:
        return default
    if max_len is not None and len(text) > max_len:
        return text[:max_len]
    return text


def _to_int(value: Any, *, default: int, min_value: int) -> int:
    if value is None:
        return default
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    return max(min_value, number)


def _to_decimal(value: Any, *, default: float | None) -> float | None:
    if value is None:
        return default
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number < 0:
        return default
    return round(number, 2)


def _to_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    return None


def _to_datetime(value: Any, *, fallback: Any = None) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(fallback, datetime):
        return fallback
    return datetime(1900, 1, 1)


def _normalize_state(value: Any) -> str | None:
    text = _clean_text(value, default=None, max_len=10)
    if text is None:
        return None
    normalized = re.sub(r"[^A-Za-z]", "", text).upper()
    if len(normalized) < 2:
        return None
    return normalized[:2]


def _resolve_situacao(is_active: Any, deleted_at: Any) -> str:
    if deleted_at is not None:
        return "Inativa"
    if is_active in (False, 0, "0", "false", "FALSE", "False"):
        return "Suspensa"
    return "Ativa"


def _build_notes(
    tipo_equipe: str | None,
    categoria_equipe: str | None,
    qtd_membros_atual: int,
    qtd_membros_total: int,
) -> str:
    tipo = tipo_equipe or "N/A"
    categoria = categoria_equipe or "N/A"
    return (
        f"Origem core.teams | tipo={tipo} | categoria={categoria} | "
        f"membros_ativos={qtd_membros_atual} | membros_total={qtd_membros_total}"
    )[:200]
