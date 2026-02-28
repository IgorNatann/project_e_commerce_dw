from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_regiao"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_regiao.sql").format(batch_size=safe_batch_size)
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
        region_id = int(raw["region_id"])
        deleted_at = raw.get("deleted_at")
        if deleted_at is not None:
            soft_deleted_count += 1

        data_cadastro = _to_datetime(raw.get("created_at"))
        data_ultima_atualizacao = _to_datetime(raw.get("updated_at"), fallback=data_cadastro)

        pais = _clean_text(raw.get("country"), default="Brasil", max_len=50)
        estado = _normalize_state(raw.get("state"), default="NA")
        cidade = _clean_text(raw.get("city"), default=f"Cidade {region_id}", max_len=100)
        nome_estado = _clean_text(raw.get("state_name"), default=estado, max_len=50)

        eh_ativo = _resolve_active(raw.get("is_active"), deleted_at=deleted_at)

        transformed = {
            "regiao_original_id": region_id,
            "pais": pais,
            "regiao_pais": _clean_text(raw.get("region_name"), default=None, max_len=30),
            "estado": estado,
            "nome_estado": nome_estado,
            "cidade": cidade,
            "codigo_ibge": _clean_text(raw.get("ibge_code"), default=None, max_len=10),
            "cep_inicial": None,
            "cep_final": None,
            "ddd": None,
            "populacao_estimada": None,
            "area_km2": None,
            "densidade_demografica": None,
            "tipo_municipio": None,
            "porte_municipio": None,
            "pib_per_capita": None,
            "idh": None,
            "latitude": None,
            "longitude": None,
            "fuso_horario": None,
            "data_cadastro": data_cadastro,
            "data_ultima_atualizacao": data_ultima_atualizacao,
            "eh_ativo": eh_ativo,
            "source_updated_at": data_ultima_atualizacao,
            "source_id": region_id,
        }
        transformed_rows.append(transformed)

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_regiao.sql")
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
        row["regiao_original_id"],
        row["pais"],
        row["regiao_pais"],
        row["estado"],
        row["nome_estado"],
        row["cidade"],
        row["codigo_ibge"],
        row["cep_inicial"],
        row["cep_final"],
        row["ddd"],
        row["populacao_estimada"],
        row["area_km2"],
        row["densidade_demografica"],
        row["tipo_municipio"],
        row["porte_municipio"],
        row["pib_per_capita"],
        row["idh"],
        row["latitude"],
        row["longitude"],
        row["fuso_horario"],
        row["data_cadastro"],
        row["data_ultima_atualizacao"],
        row["eh_ativo"],
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


def _normalize_state(value: Any, *, default: str) -> str:
    text = _clean_text(value, default=default, max_len=10)
    if text is None:
        return default
    normalized = re.sub(r"[^A-Za-z]", "", text).upper()
    if len(normalized) < 2:
        return default
    return normalized[:2]


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


def _resolve_active(value: Any, *, deleted_at: Any) -> int:
    if deleted_at is not None:
        return 0
    return _to_bit(value)
