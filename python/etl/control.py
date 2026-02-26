from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from db import execute, query_one, read_sql_file


@dataclass(frozen=True)
class EntityControl:
    entity_name: str
    watermark_updated_at: datetime
    watermark_id: int
    batch_size: int
    cutoff_minutes: int


def start_run(
    dw_connection: Any,
    *,
    entities_requested: list[str],
    started_by: str,
) -> int:
    sql = """
    INSERT INTO audit.etl_run (entities_requested, started_by, status, entities_succeeded, entities_failed)
    OUTPUT INSERTED.run_id
    VALUES (?, ?, 'running', 0, 0);
    """
    row = query_one(dw_connection, sql, (",".join(entities_requested), started_by))
    if row is None:
        raise RuntimeError("Nao foi possivel iniciar audit.etl_run.")
    return int(row["run_id"])


def finish_run(
    dw_connection: Any,
    *,
    run_id: int,
    status: str,
    entities_succeeded: int,
    entities_failed: int,
    error_message: str | None,
) -> None:
    sql = """
    UPDATE audit.etl_run
       SET finished_at = SYSUTCDATETIME(),
           status = ?,
           entities_succeeded = ?,
           entities_failed = ?,
           error_message = ?
     WHERE run_id = ?;
    """
    execute(
        dw_connection,
        sql,
        (status, int(entities_succeeded), int(entities_failed), error_message, int(run_id)),
    )


def get_entity_control(dw_connection: Any, entity_name: str) -> EntityControl:
    sql = """
    SELECT
        entity_name,
        watermark_updated_at,
        watermark_id,
        batch_size,
        cutoff_minutes
    FROM ctl.etl_control
    WHERE entity_name = ?
      AND is_active = 1;
    """
    row = query_one(dw_connection, sql, (entity_name,))
    if row is None:
        raise ValueError(
            f"Entidade '{entity_name}' nao encontrada em ctl.etl_control ou marcada como inativa."
        )

    return EntityControl(
        entity_name=row["entity_name"],
        watermark_updated_at=row["watermark_updated_at"],
        watermark_id=int(row["watermark_id"]),
        batch_size=max(1, int(row["batch_size"])),
        cutoff_minutes=max(0, int(row["cutoff_minutes"])),
    )


def start_entity_run(
    dw_connection: Any,
    *,
    run_id: int,
    entity_name: str,
    watermark_from_updated_at: datetime,
    watermark_from_id: int,
) -> int:
    sql = """
    INSERT INTO audit.etl_run_entity
    (
        run_id,
        entity_name,
        status,
        watermark_from_updated_at,
        watermark_from_id
    )
    OUTPUT INSERTED.run_entity_id
    VALUES (?, ?, 'running', ?, ?);
    """
    row = query_one(
        dw_connection,
        sql,
        (int(run_id), entity_name, watermark_from_updated_at, int(watermark_from_id)),
    )
    if row is None:
        raise RuntimeError("Nao foi possivel iniciar audit.etl_run_entity.")
    return int(row["run_entity_id"])


def finish_entity_run(
    dw_connection: Any,
    *,
    run_entity_id: int,
    status: str,
    extracted_count: int,
    upserted_count: int,
    soft_deleted_count: int,
    watermark_to_updated_at: datetime | None,
    watermark_to_id: int | None,
    error_message: str | None,
) -> None:
    sql = """
    UPDATE audit.etl_run_entity
       SET entity_finished_at = SYSUTCDATETIME(),
           status = ?,
           extracted_count = ?,
           upserted_count = ?,
           soft_deleted_count = ?,
           watermark_to_updated_at = ?,
           watermark_to_id = ?,
           error_message = ?,
           updated_at = SYSUTCDATETIME()
     WHERE run_entity_id = ?;
    """
    execute(
        dw_connection,
        sql,
        (
            status,
            int(extracted_count),
            int(upserted_count),
            int(soft_deleted_count),
            watermark_to_updated_at,
            watermark_to_id,
            error_message,
            int(run_entity_id),
        ),
    )


def mark_control_success_with_watermark(
    dw_connection: Any,
    *,
    entity_name: str,
    watermark_updated_at: datetime,
    watermark_id: int,
    run_id: int,
) -> None:
    sql = read_sql_file("update_watermark.sql")
    execute(
        dw_connection,
        sql,
        (
            watermark_updated_at,
            int(watermark_id),
            int(run_id),
            "success",
            "success",
            entity_name,
        ),
    )


def mark_control_success_without_watermark(
    dw_connection: Any,
    *,
    entity_name: str,
    run_id: int,
) -> None:
    sql = """
    UPDATE ctl.etl_control
       SET last_run_id = ?,
           last_status = 'success',
           last_success_at = SYSUTCDATETIME(),
           updated_at = SYSUTCDATETIME()
     WHERE entity_name = ?;
    """
    execute(dw_connection, sql, (int(run_id), entity_name))


def mark_control_failed(
    dw_connection: Any,
    *,
    entity_name: str,
    run_id: int,
) -> None:
    sql = """
    UPDATE ctl.etl_control
       SET last_run_id = ?,
           last_status = 'failed',
           updated_at = SYSUTCDATETIME()
     WHERE entity_name = ?;
    """
    execute(dw_connection, sql, (int(run_id), entity_name))
