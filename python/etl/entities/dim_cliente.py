from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_cliente"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_cliente.sql").format(batch_size=safe_batch_size)

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
    fallback_tipo_cliente_count = 0
    fallback_segmento_count = 0

    for raw in raw_rows:
        if raw.get("deleted_at") is not None:
            soft_deleted_count += 1

        first_signup_date = _to_date(raw.get("first_signup_date"))
        created_at = raw.get("created_at")
        if first_signup_date is None:
            if isinstance(created_at, datetime):
                first_signup_date = created_at.date()
            else:
                first_signup_date = date(1900, 1, 1)

        updated_at = raw.get("updated_at")
        if not isinstance(updated_at, datetime):
            updated_at = datetime(1900, 1, 1)

        tipo_cliente, tipo_defaulted = _normalize_tipo_cliente(
            raw.get("customer_type"),
            is_active=raw.get("is_active"),
            is_vip=raw.get("is_vip"),
            deleted_at=raw.get("deleted_at"),
        )
        segmento, segmento_defaulted = _normalize_segmento(raw.get("segment"))
        if tipo_defaulted:
            fallback_tipo_cliente_count += 1
        if segmento_defaulted:
            fallback_segmento_count += 1

        transformed = {
            "cliente_original_id": int(raw["customer_id"]),
            "nome_cliente": _clean_text(raw.get("full_name"), default="Cliente sem nome", max_len=100),
            "email": _normalize_email(raw.get("email")),
            "telefone": _clean_text(raw.get("phone"), default=None, max_len=20),
            "cpf_cnpj": _clean_text(raw.get("document_number"), default=None, max_len=18),
            "data_nascimento": _to_date(raw.get("birth_date")),
            "genero": _normalize_gender(raw.get("gender")),
            "tipo_cliente": tipo_cliente,
            "segmento": segmento,
            "score_credito": _normalize_credit_score(raw.get("credit_score")),
            "categoria_valor": _clean_text(raw.get("value_category"), default=None, max_len=20),
            "endereco_completo": _clean_text(raw.get("address_line"), default=None, max_len=200),
            "bairro": _clean_text(raw.get("district"), default=None, max_len=50),
            "cidade": _clean_text(raw.get("city"), default="N/A", max_len=100),
            "estado": _normalize_state(raw.get("state")),
            "pais": _clean_text(raw.get("country"), default="Brasil", max_len=50),
            "cep": _clean_text(raw.get("zip_code"), default=None, max_len=10),
            "data_primeiro_cadastro": first_signup_date,
            "data_ultima_compra": _to_date(raw.get("last_purchase_date")),
            "data_ultima_atualizacao": updated_at,
            "eh_ativo": _normalize_active_flag(raw.get("is_active"), raw.get("deleted_at")),
            "aceita_email_marketing": _to_bit(raw.get("accepts_email_marketing")),
            "eh_cliente_vip": _to_bit(raw.get("is_vip")),
            "source_updated_at": updated_at,
            "source_id": int(raw["customer_id"]),
        }
        transformed_rows.append(transformed)

    if fallback_tipo_cliente_count > 0 or fallback_segmento_count > 0:
        print(
            "[dim_cliente] alertas de normalizacao: "
            f"tipo_cliente_default={fallback_tipo_cliente_count}, "
            f"segmento_default={fallback_segmento_count}"
        )

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_cliente.sql")
    params = [_to_upsert_params(row) for row in rows]
    cursor = dw_connection.cursor()
    try:
        # Reduz roundtrips no SQL Server para lotes grandes.
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
        row["cliente_original_id"],
        row["nome_cliente"],
        row["email"],
        row["telefone"],
        row["cpf_cnpj"],
        row["data_nascimento"],
        row["genero"],
        row["tipo_cliente"],
        row["segmento"],
        row["score_credito"],
        row["categoria_valor"],
        row["endereco_completo"],
        row["bairro"],
        row["cidade"],
        row["estado"],
        row["pais"],
        row["cep"],
        row["data_primeiro_cadastro"],
        row["data_ultima_compra"],
        row["data_ultima_atualizacao"],
        row["eh_ativo"],
        row["aceita_email_marketing"],
        row["eh_cliente_vip"],
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


def _normalize_email(value: Any) -> str | None:
    text = _clean_text(value, default=None, max_len=100)
    if text is None:
        return None
    return text.lower()


def _normalize_gender(value: Any) -> str | None:
    text = _clean_text(value, default=None, max_len=1)
    if text is None:
        return None
    text = text.upper()
    if text in {"M", "F", "O"}:
        return text
    return None


def _normalize_tipo_cliente(
    value: Any,
    *,
    is_active: Any,
    is_vip: Any,
    deleted_at: Any,
) -> tuple[str, bool]:
    text = _normalize_key(value)
    mapping = {
        "novo": "Novo",
        "recorrente": "Recorrente",
        "vip": "VIP",
        "inativo": "Inativo",
    }
    if text in mapping:
        return mapping[text], False
    if "vip" in text:
        return "VIP", True
    if "recorr" in text:
        return "Recorrente", True
    if "inativ" in text:
        return "Inativo", True
    if "novo" in text:
        return "Novo", True

    if deleted_at is not None or _to_bit(is_active) == 0:
        return "Inativo", True
    if _to_bit(is_vip) == 1:
        return "VIP", True
    return "Novo", True


def _normalize_segmento(value: Any) -> tuple[str, bool]:
    text = _normalize_key(value)
    if text in {"pessoafisica", "fisica", "pf"}:
        return "Pessoa Fisica", False
    if text in {"pessoajuridica", "juridica", "pj"}:
        return "Pessoa Juridica", False
    if "jur" in text:
        return "Pessoa Juridica", True
    if "fis" in text:
        return "Pessoa Fisica", True
    return "Pessoa Fisica", True


def _normalize_state(value: Any) -> str:
    text = _clean_text(value, default="NA", max_len=None)
    if text is None:
        return "NA"
    normalized = re.sub(r"[^A-Za-z]", "", text).upper()
    if len(normalized) < 2:
        return "NA"
    return normalized[:2]


def _normalize_credit_score(value: Any) -> int | None:
    if value is None:
        return None
    try:
        score = int(value)
    except (TypeError, ValueError):
        return None
    if 0 <= score <= 1000:
        return score
    return None


def _normalize_active_flag(is_active: Any, deleted_at: Any) -> int:
    if deleted_at is not None:
        return 0
    return _to_bit(is_active)


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


def _normalize_key(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip().lower()
    mojibake_fixes = {
        "Ã¡": "a",
        "Ã ": "a",
        "Ã¢": "a",
        "Ã£": "a",
        "Ã©": "e",
        "Ãª": "e",
        "Ã­": "i",
        "Ã³": "o",
        "Ã´": "o",
        "Ãµ": "o",
        "Ãº": "u",
        "Ã§": "c",
    }
    for wrong, right in mojibake_fixes.items():
        text = text.replace(wrong, right)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]", "", text)
