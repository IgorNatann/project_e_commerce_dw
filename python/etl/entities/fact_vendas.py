from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "fact_vendas"

_DECIMAL_0 = Decimal("0.00")
_DECIMAL_100 = Decimal("100.00")
_DECIMAL_CENT = Decimal("0.01")

_DIM_LOOKUP_CACHE: dict[str, dict[Any, int]] | None = None
_DEFAULT_REGIAO_ID: int | None = None


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_fact_vendas.sql").format(batch_size=safe_batch_size)
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
        if raw.get("order_item_deleted_at") is not None or raw.get("order_deleted_at") is not None:
            soft_deleted_count += 1

        source_id = int(raw["order_item_id"])
        quantidade_vendida = max(1, _to_int(raw.get("quantity"), default=1, min_value=1))

        preco_unitario = _to_decimal(raw.get("unit_price"), default=_DECIMAL_0, min_value=_DECIMAL_0)
        valor_total_bruto = _to_decimal(raw.get("gross_amount"), default=None, min_value=_DECIMAL_0)
        if valor_total_bruto is None:
            valor_total_bruto = _round_money(preco_unitario * Decimal(quantidade_vendida))

        valor_total_descontos = _to_decimal(raw.get("discount_amount"), default=_DECIMAL_0, min_value=_DECIMAL_0)
        if valor_total_descontos > valor_total_bruto:
            valor_total_descontos = valor_total_bruto

        valor_total_liquido = _round_money(valor_total_bruto - valor_total_descontos)
        if valor_total_liquido < _DECIMAL_0:
            valor_total_liquido = _DECIMAL_0

        custo_total = _to_decimal(raw.get("cost_amount"), default=_DECIMAL_0, min_value=_DECIMAL_0)
        quantidade_devolvida = _to_int(raw.get("return_quantity"), default=0, min_value=0)
        if quantidade_devolvida > quantidade_vendida:
            quantidade_devolvida = quantidade_vendida

        valor_devolvido = _to_decimal(raw.get("returned_amount"), default=_DECIMAL_0, min_value=_DECIMAL_0)
        percentual_comissao = _to_decimal(
            raw.get("commission_percent"),
            default=None,
            min_value=_DECIMAL_0,
            max_value=_DECIMAL_100,
        )
        valor_comissao = _to_decimal(raw.get("commission_amount"), default=None, min_value=_DECIMAL_0)

        teve_desconto = 1 if _to_bit(raw.get("had_discount")) == 1 or valor_total_descontos > _DECIMAL_0 else 0
        data_referencia = _to_date(raw.get("order_date"))
        if data_referencia is None:
            data_referencia = _to_date(raw.get("order_item_created_at")) or date(1900, 1, 1)

        source_updated_at = _to_datetime(raw.get("source_updated_at"), fallback=raw.get("order_item_updated_at"))

        transformed_rows.append(
            {
                "venda_original_id": source_id,
                "data_referencia": data_referencia,
                "cliente_original_id": int(raw["customer_id"]),
                "produto_original_id": int(raw["product_id"]),
                "regiao_original_id": _to_int(raw.get("resolved_region_id"), default=None, min_value=1),
                "vendedor_original_id": _to_int(raw.get("seller_id"), default=None, min_value=1),
                "quantidade_vendida": quantidade_vendida,
                "preco_unitario_tabela": preco_unitario,
                "valor_total_bruto": valor_total_bruto,
                "valor_total_descontos": valor_total_descontos,
                "valor_total_liquido": valor_total_liquido,
                "custo_total": custo_total,
                "quantidade_devolvida": quantidade_devolvida,
                "valor_devolvido": valor_devolvido,
                "percentual_comissao": percentual_comissao,
                "valor_comissao": valor_comissao,
                "numero_pedido": _clean_text(
                    raw.get("order_number"),
                    default=f"ORD-{raw.get('order_id')}",
                    max_len=20,
                ),
                "teve_desconto": teve_desconto,
                "source_updated_at": source_updated_at,
                "source_id": source_id,
            }
        )

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    dim_lookup, default_regiao_id = _get_dim_lookup_cache(dw_connection)
    missing_required: dict[str, set[Any]] = {
        "data_referencia": set(),
        "cliente_original_id": set(),
        "produto_original_id": set(),
        "regiao_original_id": set(),
    }
    vendedores_sem_lookup = 0

    params: list[tuple[Any, ...]] = []
    for row in rows:
        data_id = dim_lookup["data"].get(row["data_referencia"])
        if data_id is None:
            _remember_missing(missing_required["data_referencia"], row["data_referencia"])

        cliente_id = dim_lookup["cliente"].get(row["cliente_original_id"])
        if cliente_id is None:
            _remember_missing(missing_required["cliente_original_id"], row["cliente_original_id"])

        produto_id = dim_lookup["produto"].get(row["produto_original_id"])
        if produto_id is None:
            _remember_missing(missing_required["produto_original_id"], row["produto_original_id"])

        regiao_original_id = row.get("regiao_original_id")
        regiao_id = dim_lookup["regiao"].get(regiao_original_id) if regiao_original_id is not None else None
        if regiao_id is None:
            if regiao_original_id is not None:
                _remember_missing(missing_required["regiao_original_id"], regiao_original_id)
            regiao_id = default_regiao_id

        vendedor_original_id = row.get("vendedor_original_id")
        vendedor_id = (
            dim_lookup["vendedor"].get(vendedor_original_id)
            if vendedor_original_id is not None
            else None
        )
        if vendedor_original_id is not None and vendedor_id is None:
            vendedores_sem_lookup += 1

        params.append(
            (
                row["venda_original_id"],
                data_id,
                cliente_id,
                produto_id,
                regiao_id,
                vendedor_id,
                row["quantidade_vendida"],
                row["preco_unitario_tabela"],
                row["valor_total_bruto"],
                row["valor_total_descontos"],
                row["valor_total_liquido"],
                row["custo_total"],
                row["quantidade_devolvida"],
                row["valor_devolvido"],
                row["percentual_comissao"],
                row["valor_comissao"],
                row["numero_pedido"],
                row["teve_desconto"],
            )
        )

    _raise_if_missing_dimensions(missing_required)

    if vendedores_sem_lookup > 0:
        print(
            "[fact_vendas] aviso: "
            f"{vendedores_sem_lookup} linhas com vendedor sem correspondencia na DIM_VENDEDOR; "
            "vendedor_id gravado como NULL."
        )

    sql = read_sql_file("upsert_fact_vendas.sql")
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


def _get_dim_lookup_cache(dw_connection: Any) -> tuple[dict[str, dict[Any, int]], int]:
    global _DIM_LOOKUP_CACHE
    global _DEFAULT_REGIAO_ID

    if _DIM_LOOKUP_CACHE is None:
        _DIM_LOOKUP_CACHE = {
            "data": _load_date_lookup(dw_connection),
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
            "regiao": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_REGIAO",
                natural_key="regiao_original_id",
                surrogate_key="regiao_id",
            ),
            "vendedor": _load_numeric_lookup(
                dw_connection,
                table_name="dim.DIM_VENDEDOR",
                natural_key="vendedor_original_id",
                surrogate_key="vendedor_id",
            ),
        }

        regiao_values = list(_DIM_LOOKUP_CACHE["regiao"].values())
        if not regiao_values:
            raise RuntimeError("DIM_REGIAO sem registros. Nao e possivel carregar FACT_VENDAS.")
        _DEFAULT_REGIAO_ID = min(regiao_values)

    if _DEFAULT_REGIAO_ID is None:
        raise RuntimeError("Nao foi possivel resolver regiao padrao para FACT_VENDAS.")

    return _DIM_LOOKUP_CACHE, _DEFAULT_REGIAO_ID


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
        "Nao foi possivel mapear chaves obrigatorias na FACT_VENDAS. "
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
        return min_value if default is not None else None
    return number


def _to_decimal(
    value: Any,
    *,
    default: Decimal | None,
    min_value: Decimal,
    max_value: Decimal | None = None,
) -> Decimal | None:
    if value is None:
        return default
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return default
    if number < min_value:
        return default
    if max_value is not None and number > max_value:
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


def _clean_text(value: Any, *, default: str, max_len: int) -> str:
    if value is None:
        return default
    text = str(value).strip()
    if not text:
        return default
    if len(text) > max_len:
        return text[:max_len]
    return text
