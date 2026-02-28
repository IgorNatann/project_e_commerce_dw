from __future__ import annotations

import re
import unicodedata
from datetime import datetime, timezone
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_desconto"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_desconto.sql").format(batch_size=safe_batch_size)
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
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)

    for raw in raw_rows:
        discount_id = int(raw["discount_id"])
        deleted_at = raw.get("deleted_at")
        if deleted_at is not None:
            soft_deleted_count += 1

        created_at = _to_datetime(raw.get("created_at"))
        updated_at = _to_datetime(raw.get("updated_at"), fallback=created_at)
        start_at = _to_datetime(raw.get("start_at"), fallback=created_at)
        end_at = _to_datetime_or_none(raw.get("end_at"))

        tipo_desconto = _normalize_tipo_desconto(raw.get("discount_type"))
        metodo_desconto = _normalize_metodo_desconto(raw.get("discount_method"))
        aplica_em = _normalize_aplica_em(raw.get("apply_scope"))

        total_usos_realizados = _to_int(raw.get("current_usage_count"), default=0, min_value=0)
        max_usos_total = _to_int(raw.get("max_uses_total"), default=None, min_value=0)
        situacao = _resolve_situacao(
            is_active=raw.get("is_active"),
            deleted_at=deleted_at,
            end_at=end_at,
            total_usos_realizados=total_usos_realizados,
            max_usos_total=max_usos_total,
            now_utc=now_utc,
        )
        eh_ativo = 1 if situacao == "Ativo" else 0

        transformed = {
            "desconto_original_id": discount_id,
            "codigo_desconto": _clean_text(
                raw.get("discount_code"),
                default=f"DISC-{discount_id}",
                max_len=50,
            ),
            "nome_campanha": _clean_text(raw.get("campaign_name"), default=None, max_len=150),
            "descricao": _clean_text(raw.get("description"), default=None, max_len=500),
            "tipo_desconto": tipo_desconto,
            "metodo_desconto": metodo_desconto,
            "valor_desconto": _to_decimal(raw.get("discount_value"), default=None, min_value=0.0, allow_zero=False),
            "min_valor_compra_regra": _to_decimal(raw.get("min_order_value"), default=None, min_value=0.0, allow_zero=True),
            "max_valor_desconto_regra": _to_decimal(raw.get("max_discount_value"), default=None, min_value=0.0, allow_zero=True),
            "max_usos_por_cliente": _to_int(raw.get("max_uses_per_customer"), default=None, min_value=0),
            "max_usos_total": max_usos_total,
            "aplica_em": aplica_em,
            "restricao_produtos": _clean_text(raw.get("product_restriction"), default=None, max_len=500),
            "restricao_clientes": _derive_restricao_clientes(raw.get("discount_type")),
            "data_inicio_validade": start_at,
            "data_fim_validade": end_at,
            "origem_campanha": None,
            "canal_divulgacao": None,
            "total_usos_realizados": total_usos_realizados,
            "total_receita_gerada": _to_decimal(raw.get("total_revenue_generated"), default=0.0, min_value=0.0, allow_zero=True),
            "total_desconto_concedido": _to_decimal(raw.get("total_discount_given"), default=0.0, min_value=0.0, allow_zero=True),
            "situacao": situacao,
            "eh_ativo": eh_ativo,
            "requer_aprovacao": _to_bit(raw.get("approval_required")),
            "eh_cumulativo": _to_bit(raw.get("is_stackable")),
            "data_criacao": created_at,
            "data_ultima_atualizacao": updated_at,
            "usuario_criador": None,
            "observacoes": _clean_text("Origem core.discount_campaigns", default=None, max_len=500),
            "source_updated_at": updated_at,
            "source_id": discount_id,
        }
        transformed_rows.append(transformed)

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_desconto.sql")
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
        row["desconto_original_id"],
        row["codigo_desconto"],
        row["nome_campanha"],
        row["descricao"],
        row["tipo_desconto"],
        row["metodo_desconto"],
        row["valor_desconto"],
        row["min_valor_compra_regra"],
        row["max_valor_desconto_regra"],
        row["max_usos_por_cliente"],
        row["max_usos_total"],
        row["aplica_em"],
        row["restricao_produtos"],
        row["restricao_clientes"],
        row["data_inicio_validade"],
        row["data_fim_validade"],
        row["origem_campanha"],
        row["canal_divulgacao"],
        row["total_usos_realizados"],
        row["total_receita_gerada"],
        row["total_desconto_concedido"],
        row["situacao"],
        row["eh_ativo"],
        row["requer_aprovacao"],
        row["eh_cumulativo"],
        row["data_criacao"],
        row["data_ultima_atualizacao"],
        row["usuario_criador"],
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


def _to_datetime(value: Any, *, fallback: Any = None) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(fallback, datetime):
        return fallback
    return datetime(1900, 1, 1)


def _to_datetime_or_none(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value
    return None


def _to_decimal(
    value: Any,
    *,
    default: float | None,
    min_value: float,
    allow_zero: bool,
) -> float | None:
    if value is None:
        return default
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number < min_value:
        return default
    if not allow_zero and number == 0:
        return default
    return round(number, 2)


def _to_int(value: Any, *, default: int | None, min_value: int) -> int | None:
    if value is None:
        return default
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    return max(min_value, number)


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


def _normalize_tipo_desconto(value: Any) -> str:
    text = _normalize_key(value)
    mapping = {
        "cupom": "Cupom",
        "promocaoautomatica": "Promo??o Autom?tica",
        "descontoprogressivo": "Desconto Progressivo",
        "fidelidade": "Fidelidade",
        "primeiracompra": "Primeira Compra",
        "cashback": "Cashback",
    }
    if text in mapping:
        return mapping[text]
    if "promocao" in text:
        return "Promo??o Autom?tica"
    if "progress" in text:
        return "Desconto Progressivo"
    if "primeira" in text:
        return "Primeira Compra"
    return "Cupom"


def _normalize_metodo_desconto(value: Any) -> str:
    text = _normalize_key(value)
    mapping = {
        "percentual": "Percentual",
        "valorfixo": "Valor Fixo",
        "fretegratis": "Frete Gr?tis",
        "brinde": "Brinde",
        "combo": "Combo",
    }
    if text in mapping:
        return mapping[text]
    if "frete" in text:
        return "Frete Gr?tis"
    if "fixo" in text:
        return "Valor Fixo"
    return "Percentual"


def _normalize_aplica_em(value: Any) -> str:
    text = _normalize_key(value)
    mapping = {
        "pedidototal": "Pedido Total",
        "produtoespecifico": "Produto Espec?fico",
        "categoria": "Categoria",
        "frete": "Frete",
        "itemindividual": "Item Individual",
    }
    if text in mapping:
        return mapping[text]
    if "produto" in text:
        return "Produto Espec?fico"
    if "item" in text:
        return "Item Individual"
    return "Pedido Total"


def _derive_restricao_clientes(discount_type: Any) -> str | None:
    text = _normalize_key(discount_type)
    if text == "primeiracompra":
        return "Novos Clientes"
    if text == "fidelidade":
        return "Clientes Fidelidade"
    return None


def _resolve_situacao(
    *,
    is_active: Any,
    deleted_at: Any,
    end_at: datetime | None,
    total_usos_realizados: int,
    max_usos_total: int | None,
    now_utc: datetime,
) -> str:
    if deleted_at is not None:
        return "Cancelado"
    if max_usos_total is not None and max_usos_total > 0 and total_usos_realizados >= max_usos_total:
        return "Esgotado"
    if end_at is not None and end_at < now_utc:
        return "Expirado"
    if _to_bit(is_active) == 1:
        return "Ativo"
    return "Pausado"


def _normalize_key(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]", "", text)
