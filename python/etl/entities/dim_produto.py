from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_produto"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_produto.sql").format(batch_size=safe_batch_size)

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
    fallback_status_count = 0

    for raw in raw_rows:
        deleted_at = raw.get("deleted_at")
        if deleted_at is not None:
            soft_deleted_count += 1

        status, status_defaulted = _normalize_status(raw.get("product_status"), deleted_at=deleted_at)
        if status_defaulted:
            fallback_status_count += 1

        data_cadastro = _to_datetime(raw.get("created_at"))
        data_ultima_atualizacao = _to_datetime(raw.get("updated_at"))

        product_code = _clean_text(raw.get("product_code"), default=None, max_len=50)
        sku = _clean_text(raw.get("sku"), default=None, max_len=50)

        transformed = {
            "produto_original_id": int(raw["product_id"]),
            "codigo_sku": sku or product_code or f"SKU_{int(raw['product_id'])}",
            "codigo_barras": _clean_text(raw.get("barcode"), default=None, max_len=20),
            "nome_produto": _clean_text(raw.get("product_name"), default="Produto sem nome", max_len=150),
            "descricao_curta": _clean_text(raw.get("short_description"), default=None, max_len=255),
            "descricao_completa": _clean_text(raw.get("full_description"), default=None, max_len=None),
            "categoria": _clean_text(raw.get("category_name"), default="Sem Categoria", max_len=50),
            "subcategoria": _clean_text(raw.get("subcategory_name"), default="Sem Subcategoria", max_len=50),
            "linha_produto": _clean_text(raw.get("product_line"), default=None, max_len=50),
            "marca": _clean_text(raw.get("brand"), default="Sem Marca", max_len=50),
            "fabricante": _clean_text(raw.get("manufacturer"), default=None, max_len=100),
            "fornecedor_id": _to_int(raw.get("supplier_id"), default=0, min_value=0),
            "nome_fornecedor": _clean_text(raw.get("supplier_name"), default="Fornecedor N/A", max_len=100),
            "pais_origem": _clean_text(raw.get("country_origin"), default=None, max_len=50),
            "peso_kg": _to_decimal(raw.get("weight_kg")),
            "altura_cm": _to_decimal(raw.get("height_cm")),
            "largura_cm": _to_decimal(raw.get("width_cm")),
            "profundidade_cm": _to_decimal(raw.get("depth_cm")),
            "cor_principal": _clean_text(raw.get("color"), default=None, max_len=30),
            "material": _clean_text(raw.get("material"), default=None, max_len=50),
            "preco_custo": _to_decimal(raw.get("cost_price"), default=0),
            "preco_sugerido": _to_decimal(raw.get("list_price"), default=0),
            "margem_sugerida_percent": _to_decimal(raw.get("suggested_margin_percent")),
            "eh_perecivel": _to_bit(raw.get("is_perishable")),
            "eh_fragil": _to_bit(raw.get("is_fragile")),
            "requer_refrigeracao": _to_bit(raw.get("requires_refrigeration")),
            "idade_minima_venda": _to_int(raw.get("minimum_age"), default=None, min_value=0),
            "estoque_minimo": _to_int(raw.get("min_stock"), default=0, min_value=0),
            "estoque_maximo": _to_int(raw.get("max_stock"), default=1000, min_value=0),
            "prazo_reposicao_dias": _to_int(raw.get("reorder_days"), default=None, min_value=0),
            "situacao": status,
            "data_lancamento": _to_date(raw.get("launch_date")),
            "data_descontinuacao": _to_date(raw.get("discontinued_date")),
            "data_cadastro": data_cadastro,
            "data_ultima_atualizacao": data_ultima_atualizacao,
            "palavras_chave": _clean_text(raw.get("keywords"), default=None, max_len=200),
            "avaliacao_media": _normalize_rating(raw.get("rating_avg")),
            "total_avaliacoes": _to_int(raw.get("rating_count"), default=0, min_value=0),
            "source_updated_at": data_ultima_atualizacao,
            "source_id": int(raw["product_id"]),
        }

        if transformed["estoque_maximo"] < transformed["estoque_minimo"]:
            transformed["estoque_maximo"] = transformed["estoque_minimo"]

        transformed_rows.append(transformed)

    if fallback_status_count > 0:
        print(f"[dim_produto] alertas de normalizacao: status_default={fallback_status_count}")

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_produto.sql")
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
        row["produto_original_id"],
        row["codigo_sku"],
        row["codigo_barras"],
        row["nome_produto"],
        row["descricao_curta"],
        row["descricao_completa"],
        row["categoria"],
        row["subcategoria"],
        row["linha_produto"],
        row["marca"],
        row["fabricante"],
        row["fornecedor_id"],
        row["nome_fornecedor"],
        row["pais_origem"],
        row["peso_kg"],
        row["altura_cm"],
        row["largura_cm"],
        row["profundidade_cm"],
        row["cor_principal"],
        row["material"],
        row["preco_custo"],
        row["preco_sugerido"],
        row["margem_sugerida_percent"],
        row["eh_perecivel"],
        row["eh_fragil"],
        row["requer_refrigeracao"],
        row["idade_minima_venda"],
        row["estoque_minimo"],
        row["estoque_maximo"],
        row["prazo_reposicao_dias"],
        row["situacao"],
        row["data_lancamento"],
        row["data_descontinuacao"],
        row["data_cadastro"],
        row["data_ultima_atualizacao"],
        row["palavras_chave"],
        row["avaliacao_media"],
        row["total_avaliacoes"],
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


def _to_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    return None


def _to_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    return datetime(1900, 1, 1)


def _to_decimal(value: Any, default: Any = None):
    if value is None:
        return default
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number < 0:
        return default if default is not None else None
    return number


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


def _normalize_rating(value: Any):
    rating = _to_decimal(value)
    if rating is None:
        return None
    if rating < 0:
        return 0
    if rating > 5:
        return 5
    return rating


def _normalize_status(value: Any, *, deleted_at: Any) -> tuple[str, bool]:
    if deleted_at is not None:
        return "Descontinuado", True

    text = _normalize_key(value)
    if text in {"ativo"}:
        return "Ativo", False
    if text in {"inativo"}:
        return "Inativo", False
    if text in {"descontinuado"}:
        return "Descontinuado", False

    if "descontinu" in text:
        return "Descontinuado", True
    if "inativ" in text:
        return "Inativo", True
    if "ativ" in text:
        return "Ativo", True
    return "Ativo", True


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


def _normalize_key(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]", "", text)
