from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "fact_metas"

_DECIMAL_0 = Decimal("0.00")
_DECIMAL_001 = Decimal("0.01")
_DECIMAL_100 = Decimal("100.00")
_DECIMAL_999_99 = Decimal("999.99")
_DECIMAL_CENT = Decimal("0.01")

_DIM_LOOKUP_CACHE: dict[str, dict[Any, int]] | None = None


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_fact_metas.sql").format(batch_size=safe_batch_size)
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
        if raw.get("target_deleted_at") is not None:
            soft_deleted_count += 1

        source_id = int(raw["seller_target_id"])
        raw_seller_id = raw.get("seller_id")
        vendedor_original_id = _to_int(raw_seller_id, default=None, min_value=1)
        if vendedor_original_id is None:
            raise ValueError(
                f"[fact_metas] seller_id invalido ({raw_seller_id}) para seller_target_id={source_id}."
            )

        data_referencia = _to_month_start_date(raw.get("target_month"))
        if data_referencia is None:
            raise ValueError(f"[fact_metas] target_month invalido para seller_target_id={source_id}.")

        valor_meta = _to_decimal(raw.get("target_amount"), default=None, min_value=_DECIMAL_001)
        if valor_meta is None:
            raise ValueError(f"[fact_metas] target_amount invalido para seller_target_id={source_id}.")

        quantidade_meta = _to_int(raw.get("target_quantity"), default=None, min_value=1)
        valor_realizado = _to_decimal(
            raw.get("realized_amount"),
            default=_DECIMAL_0,
            min_value=_DECIMAL_0,
        )
        if valor_realizado is None:
            valor_realizado = _DECIMAL_0

        quantidade_realizada = _to_int(raw.get("realized_quantity"), default=0, min_value=0)
        if quantidade_realizada is None:
            quantidade_realizada = 0

        percentual_atingido = _round_money((valor_realizado / valor_meta) * _DECIMAL_100)
        if percentual_atingido > _DECIMAL_999_99:
            percentual_atingido = _DECIMAL_999_99
        gap_meta = _round_money(valor_realizado - valor_meta)
        ticket_medio_realizado = None
        if quantidade_realizada > 0:
            ticket_medio_realizado = _round_money(
                valor_realizado / Decimal(quantidade_realizada)
            )

        source_updated_at = _to_datetime(raw.get("target_updated_at"), fallback=raw.get("target_created_at"))
        data_inclusao = _to_datetime(raw.get("target_created_at"), fallback=source_updated_at)
        tipo_periodo = _normalize_period_type(raw.get("period_type"))

        transformed_rows.append(
            {
                "vendedor_original_id": vendedor_original_id,
                "data_referencia": data_referencia,
                "tipo_periodo": tipo_periodo,
                "valor_meta": valor_meta,
                "quantidade_meta": quantidade_meta,
                "valor_realizado": valor_realizado,
                "quantidade_realizada": quantidade_realizada,
                "percentual_atingido": percentual_atingido,
                "gap_meta": gap_meta,
                "ticket_medio_realizado": ticket_medio_realizado,
                "meta_batida": 1 if valor_realizado >= valor_meta else 0,
                "meta_superada": 1 if valor_realizado > valor_meta else 0,
                "eh_periodo_fechado": _to_bit(raw.get("period_closed")),
                "data_inclusao": data_inclusao,
                "data_ultima_atualizacao": source_updated_at,
                "source_updated_at": source_updated_at,
                "source_id": source_id,
            }
        )

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    dim_lookup = _get_dim_lookup_cache(dw_connection)
    missing_required: dict[str, set[Any]] = {
        "data_referencia": set(),
        "vendedor_original_id": set(),
    }

    params: list[tuple[Any, ...]] = []
    for row in rows:
        data_id = dim_lookup["data"].get(row["data_referencia"])
        if data_id is None:
            _remember_missing(missing_required["data_referencia"], row["data_referencia"])

        vendedor_id = dim_lookup["vendedor"].get(row["vendedor_original_id"])
        if vendedor_id is None:
            _remember_missing(
                missing_required["vendedor_original_id"],
                row["vendedor_original_id"],
            )

        params.append(
            (
                vendedor_id,
                data_id,
                row["tipo_periodo"],
                row["valor_meta"],
                row["quantidade_meta"],
                row["valor_realizado"],
                row["quantidade_realizada"],
                row["percentual_atingido"],
                row["gap_meta"],
                row["ticket_medio_realizado"],
                row["meta_batida"],
                row["meta_superada"],
                row["eh_periodo_fechado"],
                row["data_inclusao"],
                row["data_ultima_atualizacao"],
            )
        )

    _raise_if_missing_dimensions(missing_required)

    sql = read_sql_file("upsert_fact_metas.sql")
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


def _get_dim_lookup_cache(dw_connection: Any) -> dict[str, dict[Any, int]]:
    global _DIM_LOOKUP_CACHE

    if _DIM_LOOKUP_CACHE is None:
        _DIM_LOOKUP_CACHE = {
            "data": _load_date_lookup(dw_connection),
            "vendedor": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_VENDEDOR",
                natural_key="vendedor_original_id",
                surrogate_key="vendedor_id",
            ),
        }

    return _DIM_LOOKUP_CACHE


def _load_date_lookup(dw_connection: Any) -> dict[date, int]:
    rows = query_all(
        dw_connection,
        """
        SELECT data_completa, data_id
        FROM dim.DIM_DATA;
        """,
    )
    lookup: dict[date, int] = {}
    for row in rows:
        dt = _to_date(row.get("data_completa"))
        if dt is None:
            continue
        lookup[dt] = int(row["data_id"])
    return lookup


def _load_numeric_lookup(
    dw_connection: Any,
    *,
    table_name: str,
    natural_key: str,
    surrogate_key: str,
) -> dict[int, int]:
    rows = query_all(
        dw_connection,
        f"""
        SELECT {natural_key}, {surrogate_key}
        FROM {table_name};
        """,
    )
    lookup: dict[int, int] = {}
    for row in rows:
        natural = row.get(natural_key)
        surrogate = row.get(surrogate_key)
        if natural is None or surrogate is None:
            continue
        try:
            lookup[int(natural)] = int(surrogate)
        except (TypeError, ValueError):
            continue
    return lookup


def _remember_missing(bucket: set[Any], value: Any, limit: int = 5) -> None:
    if len(bucket) < limit:
        bucket.add(value)


def _raise_if_missing_dimensions(missing_required: dict[str, set[Any]]) -> None:
    details: list[str] = []
    for key, values in missing_required.items():
        if not values:
            continue
        sample = ", ".join(str(value) for value in sorted(values))
        details.append(f"{key}: {sample}")
    if not details:
        return
    raise ValueError(
        "Nao foi possivel mapear chaves obrigatorias na FACT_METAS. "
        + " | ".join(details)
    )


def _to_int(value: Any, *, default: int | None, min_value: int | None) -> int | None:
    if value is None:
        return default
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    if min_value is not None and number < min_value:
        return default
    return number


def _to_decimal(
    value: Any,
    *,
    default: Decimal | None,
    min_value: Decimal,
) -> Decimal | None:
    if value is None:
        return default
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return default
    if number < min_value:
        return default
    return _round_money(number)


def _round_money(value: Decimal) -> Decimal:
    return value.quantize(_DECIMAL_CENT, rounding=ROUND_HALF_UP)


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


def _to_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    return None


def _to_month_start_date(value: Any) -> date | None:
    dt = _to_date(value)
    if dt is None:
        return None
    return date(dt.year, dt.month, 1)


def _to_datetime(value: Any, *, fallback: Any = None) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(fallback, datetime):
        return fallback
    return datetime(1900, 1, 1)


def _normalize_period_type(value: Any) -> str:
    if value is None:
        return "Mensal"
    normalized = str(value).strip().lower()
    if normalized == "trimestral":
        return "Trimestral"
    if normalized == "anual":
        return "Anual"
    return "Mensal"
