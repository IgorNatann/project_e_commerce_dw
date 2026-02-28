from __future__ import annotations

import re
from datetime import date, datetime
from typing import Any

from db import query_all, read_sql_file


ENTITY_NAME = "dim_vendedor"


def extract_batch(
    oltp_connection: Any,
    *,
    watermark_updated_at: datetime,
    watermark_id: int,
    cutoff_updated_at: datetime,
    batch_size: int,
) -> list[dict[str, Any]]:
    safe_batch_size = max(1, int(batch_size))
    sql = read_sql_file("extract_dim_vendedor.sql").format(batch_size=safe_batch_size)
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
        seller_id = int(raw["seller_id"])
        deleted_at = raw.get("deleted_at")
        if deleted_at is not None:
            soft_deleted_count += 1

        seller_code = _clean_text(raw.get("seller_code"), default=f"SELL-{seller_id:05d}", max_len=20)
        seller_name = _clean_text(raw.get("seller_name"), default=f"Vendedor {seller_id}", max_len=100)
        team_name = _clean_text(raw.get("team_name"), default=None, max_len=100)
        team_type = _clean_text(raw.get("team_type"), default=None, max_len=30)
        team_category = _clean_text(raw.get("team_category"), default=None, max_len=30)
        home_state = _normalize_state(raw.get("home_state"))
        home_city = _clean_text(raw.get("home_city"), default=None, max_len=100)

        situacao = _normalize_situacao(raw.get("seller_status"), deleted_at=deleted_at)
        eh_ativo = 1 if situacao == "Ativo" else 0
        eh_lider = _to_bit(raw.get("is_team_leader"))
        aceita_novos_clientes = 1 if eh_ativo == 1 else 0

        updated_at = _to_datetime(raw.get("updated_at"), fallback=raw.get("created_at"))
        hired_at = _to_date(raw.get("hire_date")) or _to_date(raw.get("created_at")) or date(1900, 1, 1)
        monthly_goal = _to_decimal(raw.get("monthly_goal_amount"), default=0.0)
        quarterly_goal = None if monthly_goal is None else round(monthly_goal * 3.0, 2)
        tipo_vendedor = _normalize_tipo_vendedor(team_type)
        percentual_comissao = _default_commission(tipo_vendedor)

        gerente_id = None
        manager_name = _clean_text(raw.get("manager_name"), default=None, max_len=100)
        territory = _build_territory(home_state, home_city)
        seller_email = _build_email(seller_code, seller_id)
        matricula = _build_matricula(seller_code, seller_id)

        transformed = {
            "vendedor_original_id": seller_id,
            "nome_vendedor": seller_name,
            "nome_exibicao": seller_name,
            "cpf": None,
            "matricula": matricula,
            "email": seller_email,
            "email_pessoal": None,
            "telefone_celular": None,
            "telefone_comercial": None,
            "cargo": _resolve_cargo(team_type, eh_lider),
            "nivel_senioridade": _resolve_seniority(hired_at),
            "departamento": "Comercial",
            "area": team_category,
            # equipe_id e gerente_id dependem de chaves surrogate no DW.
            # Enquanto dim_equipe e a hierarquia de vendedores nao estiverem populadas,
            # mantemos nulo para nao violar FKs.
            "equipe_id": None,
            "nome_equipe": team_name,
            "gerente_id": gerente_id,
            "nome_gerente": manager_name,
            "estado_atuacao": home_state,
            "cidade_atuacao": home_city,
            "territorio_vendas": territory,
            "tipo_vendedor": tipo_vendedor,
            "meta_mensal_base": monthly_goal,
            "meta_trimestral_base": quarterly_goal,
            "percentual_comissao_padrao": percentual_comissao,
            "tipo_comissao": "Percentual",
            "total_vendas_mes_atual": None,
            "total_vendas_mes_anterior": None,
            "percentual_meta_mes_anterior": None,
            "ranking_mes_anterior": None,
            "total_vendas_acumulado_ano": None,
            "data_contratacao": hired_at,
            "data_primeira_venda": None,
            "data_ultima_venda": None,
            "data_desligamento": _to_date(deleted_at) if deleted_at is not None else None,
            "data_ultima_atualizacao": updated_at,
            "situacao": situacao,
            "eh_ativo": eh_ativo,
            "eh_lider": eh_lider,
            "aceita_novos_clientes": aceita_novos_clientes,
            "observacoes": _build_notes(team_type, raw.get("seller_status")),
            "motivo_desligamento": _build_offboarding_reason(situacao, deleted_at),
            "source_updated_at": updated_at,
            "source_id": seller_id,
        }
        transformed_rows.append(transformed)

    return transformed_rows, soft_deleted_count


def upsert_rows(dw_connection: Any, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    sql = read_sql_file("upsert_dim_vendedor.sql")
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
        row["vendedor_original_id"],
        row["nome_vendedor"],
        row["nome_exibicao"],
        row["cpf"],
        row["matricula"],
        row["email"],
        row["email_pessoal"],
        row["telefone_celular"],
        row["telefone_comercial"],
        row["cargo"],
        row["nivel_senioridade"],
        row["departamento"],
        row["area"],
        row["equipe_id"],
        row["nome_equipe"],
        row["gerente_id"],
        row["nome_gerente"],
        row["estado_atuacao"],
        row["cidade_atuacao"],
        row["territorio_vendas"],
        row["tipo_vendedor"],
        row["meta_mensal_base"],
        row["meta_trimestral_base"],
        row["percentual_comissao_padrao"],
        row["tipo_comissao"],
        row["total_vendas_mes_atual"],
        row["total_vendas_mes_anterior"],
        row["percentual_meta_mes_anterior"],
        row["ranking_mes_anterior"],
        row["total_vendas_acumulado_ano"],
        row["data_contratacao"],
        row["data_primeira_venda"],
        row["data_ultima_venda"],
        row["data_desligamento"],
        row["data_ultima_atualizacao"],
        row["situacao"],
        row["eh_ativo"],
        row["eh_lider"],
        row["aceita_novos_clientes"],
        row["observacoes"],
        row["motivo_desligamento"],
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


def _to_bit(value: Any) -> int:
    if value in (True, 1, "1", "true", "TRUE", "True"):
        return 1
    return 0


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


def _normalize_situacao(value: Any, *, deleted_at: Any) -> str:
    if deleted_at is not None:
        return "Desligado"
    text = str(value).strip().lower() if value is not None else ""
    if text == "ativo":
        return "Ativo"
    if text == "inativo":
        return "Suspenso"
    if text == "afastado":
        return "Afastado"
    if text == "suspenso":
        return "Suspenso"
    if "deslig" in text:
        return "Desligado"
    if "afast" in text:
        return "Afastado"
    if "susp" in text or "inativ" in text:
        return "Suspenso"
    return "Ativo"


def _normalize_tipo_vendedor(team_type: str | None) -> str:
    if team_type is None:
        return "Hibrido"
    team_type_lower = team_type.lower()
    if "inside" in team_type_lower:
        return "Interno"
    if "field" in team_type_lower:
        return "Externo"
    return "Hibrido"


def _default_commission(tipo_vendedor: str) -> float:
    if tipo_vendedor == "Externo":
        return 3.0
    if tipo_vendedor == "Interno":
        return 2.0
    return 2.5


def _resolve_cargo(team_type: str | None, eh_lider: int) -> str:
    if eh_lider == 1:
        return "Lider Comercial"
    if team_type is None:
        return "Consultor Comercial"
    team_type_lower = team_type.lower()
    if "inside" in team_type_lower:
        return "Executivo Inside Sales"
    if "field" in team_type_lower:
        return "Executivo Field Sales"
    return "Consultor Comercial"


def _resolve_seniority(hire_date: date) -> str:
    years = max(0, (date.today() - hire_date).days // 365)
    if years >= 8:
        return "Especialista"
    if years >= 4:
        return "Senior"
    if years >= 2:
        return "Pleno"
    return "Junior"


def _build_territory(state: str | None, city: str | None) -> str | None:
    if state and city:
        return f"{state} - {city}"
    if state:
        return state
    return city


def _slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", ".", value.lower())
    slug = slug.strip(".")
    return slug or "vendedor"


def _build_email(seller_code: str | None, seller_id: int) -> str:
    base = seller_code or f"seller-{seller_id}"
    return f"{_slugify(base)}@empresa.local"


def _build_matricula(seller_code: str | None, seller_id: int) -> str:
    base = seller_code or f"{seller_id:05d}"
    cleaned = re.sub(r"[^A-Za-z0-9-]", "", base).upper()
    return f"MAT-{cleaned}"[:20]


def _build_notes(team_type: str | None, seller_status: Any) -> str | None:
    status_text = _clean_text(seller_status, default=None, max_len=30)
    if team_type and status_text:
        return f"Origem core.sellers | tipo={team_type} | status={status_text}"[:200]
    if team_type:
        return f"Origem core.sellers | tipo={team_type}"[:200]
    if status_text:
        return f"Origem core.sellers | status={status_text}"[:200]
    return "Origem core.sellers"


def _build_offboarding_reason(situacao: str, deleted_at: Any) -> str | None:
    if deleted_at is not None:
        return "Soft delete na origem OLTP"
    if situacao == "Suspenso":
        return "Status inativo na origem OLTP"
    if situacao == "Afastado":
        return "Status afastado na origem OLTP"
    return None
