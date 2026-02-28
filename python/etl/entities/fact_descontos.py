from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "fact_descontos"

_DECIMAL_0 = Decimal("0.00")
_DECIMAL_100 = Decimal("100.00")
_DECIMAL_CENT = Decimal("0.01")

_DIM_LOOKUP_CACHE: dict[str, Any] | None = None


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_fact_descontos.sql").format(batch_size=safe_batch_size)
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
        if (
            raw.get("order_item_discount_deleted_at") is not None
            or raw.get("order_item_deleted_at") is not None
            or raw.get("order_deleted_at") is not None
        ):
            soft_deleted_count += 1

        source_id = int(raw["order_item_discount_id"])
        desconto_original_id = _to_int(raw.get("discount_id"), default=None, min_value=0)
        if desconto_original_id is None:
            raise ValueError(
                f"[fact_descontos] discount_id invalido para order_item_discount_id={source_id}."
            )

        venda_original_id = _to_int(raw.get("order_item_id"), default=None, min_value=0)
        if venda_original_id is None:
            raise ValueError(
                f"[fact_descontos] order_item_id invalido para order_item_discount_id={source_id}."
            )

        cliente_original_id = _to_int(raw.get("customer_id"), default=None, min_value=0)
        if cliente_original_id is None:
            raise ValueError(
                f"[fact_descontos] customer_id invalido para order_item_discount_id={source_id}."
            )

        produto_original_id = _to_int(raw.get("product_id"), default=None, min_value=0)

        valor_desconto_aplicado = _to_decimal(
            raw.get("discount_amount"),
            default=_DECIMAL_0,
            min_value=_DECIMAL_0,
        )
        valor_sem_desconto = _to_decimal(
            raw.get("base_amount"),
            default=_DECIMAL_0,
            min_value=_DECIMAL_0,
        )
        if valor_desconto_aplicado > valor_sem_desconto:
            valor_desconto_aplicado = valor_sem_desconto

        valor_com_desconto = _to_decimal(
            raw.get("final_amount"),
            default=None,
            min_value=_DECIMAL_0,
        )
        valor_final_esperado = _round_money(valor_sem_desconto - valor_desconto_aplicado)
        if valor_com_desconto is None or valor_com_desconto != valor_final_esperado:
            valor_com_desconto = valor_final_esperado

        percentual_desconto_efetivo = _DECIMAL_0
        if valor_sem_desconto > _DECIMAL_0:
            percentual_desconto_efetivo = _round_money(
                (valor_desconto_aplicado / valor_sem_desconto) * _DECIMAL_100
            )
            if percentual_desconto_efetivo > _DECIMAL_100:
                percentual_desconto_efetivo = _DECIMAL_100

        data_aplicacao = _to_date(raw.get("applied_at"))
        if data_aplicacao is None:
            data_aplicacao = _to_date(raw.get("order_item_discount_created_at")) or date(1900, 1, 1)

        source_updated_at = _to_datetime(
            raw.get("source_updated_at"),
            fallback=raw.get("order_item_discount_updated_at"),
        )
        data_inclusao = _to_datetime(raw.get("order_item_discount_created_at"), fallback=source_updated_at)

        transformed_rows.append(
            {
                "desconto_aplicado_original_id": source_id,
                "desconto_original_id": desconto_original_id,
                "venda_original_id": venda_original_id,
                "data_aplicacao": data_aplicacao,
                "cliente_original_id": cliente_original_id,
                "produto_original_id": produto_original_id,
                "nivel_aplicacao": _normalize_application_level(raw.get("application_level")),
                "valor_desconto_aplicado": valor_desconto_aplicado,
                "valor_sem_desconto": valor_sem_desconto,
                "valor_com_desconto": valor_com_desconto,
                "percentual_desconto_efetivo": percentual_desconto_efetivo,
                "desconto_aprovado": _to_bit(raw.get("approved")),
                "motivo_rejeicao": _clean_text_nullable(raw.get("rejection_reason"), max_len=200),
                "numero_pedido": _clean_text(
                    raw.get("order_number"),
                    default=f"ORD-{raw.get('order_id')}",
                    max_len=20,
                ),
                "data_inclusao": data_inclusao,
                "data_atualizacao": source_updated_at,
                "source_updated_at": source_updated_at,
                "source_id": source_id,
            }
        )

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    dim_lookup = _get_lookup_cache(dw_connection)
    missing_required: dict[str, set[Any]] = {
        "desconto_original_id": set(),
        "venda_original_id": set(),
        "data_aplicacao": set(),
        "cliente_original_id": set(),
        "produto_original_id": set(),
    }

    params: list[tuple[Any, ...]] = []
    for row in rows:
        desconto_id = dim_lookup["desconto"].get(row["desconto_original_id"])
        if desconto_id is None:
            _remember_missing(missing_required["desconto_original_id"], row["desconto_original_id"])

        venda_data = dim_lookup["venda"].get(row["venda_original_id"])
        if venda_data is None:
            _remember_missing(missing_required["venda_original_id"], row["venda_original_id"])
            venda_id = None
            custo_total = _DECIMAL_0
        else:
            venda_id = venda_data["venda_id"]
            custo_total = venda_data["custo_total"]

        data_aplicacao_id = dim_lookup["data"].get(row["data_aplicacao"])
        if data_aplicacao_id is None:
            _remember_missing(missing_required["data_aplicacao"], row["data_aplicacao"])

        cliente_id = dim_lookup["cliente"].get(row["cliente_original_id"])
        if cliente_id is None:
            _remember_missing(missing_required["cliente_original_id"], row["cliente_original_id"])

        produto_id = None
        produto_original_id = row.get("produto_original_id")
        if produto_original_id is not None:
            produto_id = dim_lookup["produto"].get(produto_original_id)
            if produto_id is None:
                _remember_missing(missing_required["produto_original_id"], produto_original_id)

        margem_antes = _round_money(row["valor_sem_desconto"] - custo_total)
        margem_apos = _round_money(row["valor_com_desconto"] - custo_total)
        impacto_margem = _round_money(margem_antes - margem_apos)
        if impacto_margem < _DECIMAL_0:
            impacto_margem = _DECIMAL_0

        params.append(
            (
                row["desconto_aplicado_original_id"],
                desconto_id,
                venda_id,
                data_aplicacao_id,
                cliente_id,
                produto_id,
                row["nivel_aplicacao"],
                row["valor_desconto_aplicado"],
                row["valor_sem_desconto"],
                row["valor_com_desconto"],
                margem_antes,
                margem_apos,
                impacto_margem,
                row["percentual_desconto_efetivo"],
                row["desconto_aprovado"],
                row["motivo_rejeicao"],
                row["numero_pedido"],
                row["data_inclusao"],
                row["data_atualizacao"],
            )
        )

    _raise_if_missing_dimensions(missing_required)

    sql = read_sql_file("upsert_fact_descontos.sql")
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


def _get_lookup_cache(dw_connection: Any) -> dict[str, Any]:
    global _DIM_LOOKUP_CACHE

    if _DIM_LOOKUP_CACHE is None:
        _DIM_LOOKUP_CACHE = {
            "data": _load_date_lookup(dw_connection),
            "desconto": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_DESCONTO",
                natural_key="desconto_original_id",
                surrogate_key="desconto_id",
            ),
            "cliente": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_CLIENTE",
                natural_key="cliente_original_id",
                surrogate_key="cliente_id",
            ),
            "produto": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_PRODUTO",
                natural_key="produto_original_id",
                surrogate_key="produto_id",
            ),
            "venda": _load_sale_lookup(dw_connection),
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


def _load_sale_lookup(dw_connection: Any) -> dict[int, dict[str, Any]]:
    rows = query_all(
        dw_connection,
        """
        SELECT venda_original_id, venda_id, custo_total
        FROM fact.FACT_VENDAS;
        """,
    )
    lookup: dict[int, dict[str, Any]] = {}
    for row in rows:
        venda_original_id = row.get("venda_original_id")
        venda_id = row.get("venda_id")
        if venda_original_id is None or venda_id is None:
            continue
        try:
            lookup[int(venda_original_id)] = {
                "venda_id": int(venda_id),
                "custo_total": _to_decimal(
                    row.get("custo_total"),
                    default=_DECIMAL_0,
                    min_value=_DECIMAL_0,
                ),
            }
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
        "Nao foi possivel mapear chaves obrigatorias na FACT_DESCONTOS. "
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


def _to_datetime(value: Any, *, fallback: Any = None) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(fallback, datetime):
        return fallback
    return datetime(1900, 1, 1)


def _normalize_application_level(value: Any) -> str:
    if value is None:
        return "Pedido"
    normalized = str(value).strip().lower()
    if normalized == "item":
        return "Item"
    if normalized == "pedido":
        return "Pedido"
    if normalized == "frete":
        return "Frete"
    if normalized == "categoria":
        return "Categoria"
    return "Pedido"


def _clean_text(value: Any, *, default: str, max_len: int) -> str:
    if value is None:
        return default
    text = str(value).strip()
    if not text:
        return default
    if len(text) > max_len:
        return text[:max_len]
    return text


def _clean_text_nullable(value: Any, *, max_len: int) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if len(text) > max_len:
        return text[:max_len]
    return text
