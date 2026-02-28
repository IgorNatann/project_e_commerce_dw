from __future__ import annotations

import argparse
import getpass
import traceback
from datetime import datetime, timedelta, timezone

from config import ETLConfig
from control import (
    finish_entity_run,
    finish_run,
    get_entity_control,
    mark_control_failed,
    mark_control_success_with_watermark,
    mark_control_success_without_watermark,
    start_entity_run,
    start_run,
)
from db import close_quietly, connect_sqlserver
from entities import get_entity, list_entities


def parse_args() -> argparse.Namespace:
    available_entities = list_entities()
    parser = argparse.ArgumentParser(description="Runner ETL incremental (fase 3 - didatico).")
    parser.add_argument(
        "--entity",
        default=available_entities[0],
        choices=available_entities + ["all"],
        help="Entidade para executar. Use 'all' para todas registradas.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=None,
        help="Sobrescreve batch_size configurado no ctl.etl_control.",
    )
    parser.add_argument(
        "--cutoff-minutes",
        type=int,
        default=None,
        help="Sobrescreve cutoff_minutes configurado no ctl.etl_control.",
    )
    parser.add_argument(
        "--max-batches",
        type=int,
        default=None,
        help="Limite de lotes por entidade (util para teste).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Executa extracao/transformacao sem gravar upsert e sem avancar watermark.",
    )
    return parser.parse_args()


def utcnow_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def main() -> int:
    args = parse_args()
    config = ETLConfig.from_env()

    entity_names = list_entities() if args.entity == "all" else [args.entity]
    started_by = getpass.getuser()

    oltp_connection = None
    dw_connection = None
    run_id: int | None = None

    print(f"Entidades selecionadas: {', '.join(entity_names)}")
    print(f"Modo dry-run: {'sim' if args.dry_run else 'nao'}")

    try:
        oltp_connection = connect_sqlserver(
            config.oltp_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )
        dw_connection = connect_sqlserver(
            config.dw_conn_str,
            command_timeout_seconds=config.command_timeout_seconds,
        )

        run_id = start_run(
            dw_connection,
            entities_requested=entity_names,
            started_by=started_by,
        )
        dw_connection.commit()
        print(f"Run iniciado: run_id={run_id}")

        entities_succeeded = 0
        entities_failed = 0
        errors: list[str] = []

        for entity_name in entity_names:
            ok, error_message = run_entity(
                entity_name=entity_name,
                oltp_connection=oltp_connection,
                dw_connection=dw_connection,
                run_id=run_id,
                default_batch_size=config.default_batch_size,
                default_cutoff_minutes=config.default_cutoff_minutes,
                batch_size_override=args.batch_size,
                cutoff_minutes_override=args.cutoff_minutes,
                dry_run=args.dry_run,
                max_batches=args.max_batches,
            )

            if ok:
                entities_succeeded += 1
            else:
                entities_failed += 1
                if error_message:
                    errors.append(f"{entity_name}: {error_message}")

        final_status = _resolve_run_status(
            entities_succeeded=entities_succeeded,
            entities_failed=entities_failed,
        )
        final_error = " | ".join(errors)[:4000] if errors else None

        finish_run(
            dw_connection,
            run_id=run_id,
            status=final_status,
            entities_succeeded=entities_succeeded,
            entities_failed=entities_failed,
            error_message=final_error,
        )
        dw_connection.commit()

        print("")
        print("Resumo final")
        print(f"- run_id: {run_id}")
        print(f"- status: {final_status}")
        print(f"- entidades com sucesso: {entities_succeeded}")
        print(f"- entidades com falha: {entities_failed}")

        return 0 if entities_failed == 0 else 1

    except Exception as exc:  # noqa: BLE001
        if dw_connection is not None:
            dw_connection.rollback()

        error_text = f"{type(exc).__name__}: {exc}"
        print(f"Falha fatal no runner: {error_text}")
        traceback.print_exc()

        if run_id is not None and dw_connection is not None:
            try:
                finish_run(
                    dw_connection,
                    run_id=run_id,
                    status="failed",
                    entities_succeeded=0,
                    entities_failed=len(entity_names),
                    error_message=error_text[:4000],
                )
                dw_connection.commit()
            except Exception:  # noqa: BLE001
                dw_connection.rollback()

        return 1

    finally:
        close_quietly(oltp_connection)
        close_quietly(dw_connection)


def run_entity(
    *,
    entity_name: str,
    oltp_connection,
    dw_connection,
    run_id: int,
    default_batch_size: int,
    default_cutoff_minutes: int,
    batch_size_override: int | None,
    cutoff_minutes_override: int | None,
    dry_run: bool,
    max_batches: int | None,
) -> tuple[bool, str | None]:
    entity = get_entity(entity_name)
    control = get_entity_control(dw_connection, entity_name)

    batch_size = (
        batch_size_override
        if batch_size_override is not None
        else (control.batch_size if control.batch_size is not None else default_batch_size)
    )
    cutoff_minutes = (
        cutoff_minutes_override
        if cutoff_minutes_override is not None
        else (control.cutoff_minutes if control.cutoff_minutes is not None else default_cutoff_minutes)
    )
    batch_size = max(1, int(batch_size))
    cutoff_minutes = max(0, int(cutoff_minutes))

    print("")
    print(f"[{entity_name}] inicio")
    print(
        f"[{entity_name}] watermark atual: "
        f"{control.watermark_updated_at} / {control.watermark_id}"
    )
    print(
        f"[{entity_name}] parametros: batch_size={batch_size}, cutoff_minutes={cutoff_minutes}"
    )

    run_entity_id = start_entity_run(
        dw_connection,
        run_id=run_id,
        entity_name=entity_name,
        watermark_from_updated_at=control.watermark_updated_at,
        watermark_from_id=control.watermark_id,
    )
    dw_connection.commit()

    total_extracted = 0
    total_upserted = 0
    total_soft_deleted = 0

    watermark_to_updated_at = control.watermark_updated_at
    watermark_to_id = control.watermark_id

    batches_executed = 0

    try:
        while True:
            cutoff_updated_at = utcnow_naive() - timedelta(minutes=cutoff_minutes)
            raw_rows = entity.extract_batch(
                oltp_connection,
                watermark_updated_at=watermark_to_updated_at,
                watermark_id=watermark_to_id,
                cutoff_updated_at=cutoff_updated_at,
                batch_size=batch_size,
            )

            if not raw_rows:
                print(f"[{entity_name}] sem novos registros.")
                break

            transformed_rows, soft_deleted_count = entity.transform_rows(raw_rows)

            if not dry_run:
                upserted_count = entity.upsert_rows(dw_connection, transformed_rows)
                dw_connection.commit()
            else:
                upserted_count = len(transformed_rows)

            total_extracted += len(raw_rows)
            total_upserted += upserted_count
            total_soft_deleted += soft_deleted_count

            watermark_to_updated_at, watermark_to_id = entity.get_batch_watermark(transformed_rows)
            batches_executed += 1

            print(
                f"[{entity_name}] lote {batches_executed}: "
                f"extraidos={len(raw_rows)} upsertados={upserted_count} "
                f"soft_deleted={soft_deleted_count} "
                f"watermark={watermark_to_updated_at}/{watermark_to_id}"
            )

            if max_batches is not None and batches_executed >= max_batches:
                print(f"[{entity_name}] limite max_batches atingido ({max_batches}).")
                break

            if len(raw_rows) < batch_size:
                break

        if not dry_run:
            if total_extracted > 0:
                mark_control_success_with_watermark(
                    dw_connection,
                    entity_name=entity_name,
                    watermark_updated_at=watermark_to_updated_at,
                    watermark_id=watermark_to_id,
                    run_id=run_id,
                )
            else:
                mark_control_success_without_watermark(
                    dw_connection,
                    entity_name=entity_name,
                    run_id=run_id,
                )
            dw_connection.commit()

        finish_entity_run(
            dw_connection,
            run_entity_id=run_entity_id,
            status="success",
            extracted_count=total_extracted,
            upserted_count=total_upserted,
            soft_deleted_count=total_soft_deleted,
            watermark_to_updated_at=watermark_to_updated_at,
            watermark_to_id=watermark_to_id,
            error_message=None,
        )
        dw_connection.commit()

        print(
            f"[{entity_name}] concluido com sucesso. "
            f"extraidos={total_extracted}, upsertados={total_upserted}."
        )
        return True, None

    except Exception as exc:  # noqa: BLE001
        dw_connection.rollback()
        error_text = f"{type(exc).__name__}: {exc}"
        print(f"[{entity_name}] falha: {error_text}")
        traceback.print_exc()

        try:
            finish_entity_run(
                dw_connection,
                run_entity_id=run_entity_id,
                status="failed",
                extracted_count=total_extracted,
                upserted_count=total_upserted,
                soft_deleted_count=total_soft_deleted,
                watermark_to_updated_at=watermark_to_updated_at,
                watermark_to_id=watermark_to_id,
                error_message=error_text[:4000],
            )
            mark_control_failed(
                dw_connection,
                entity_name=entity_name,
                run_id=run_id,
            )
            dw_connection.commit()
        except Exception:  # noqa: BLE001
            dw_connection.rollback()

        return False, error_text


def _resolve_run_status(*, entities_succeeded: int, entities_failed: int) -> str:
    if entities_failed == 0:
        return "success"
    if entities_succeeded > 0:
        return "partial"
    return "failed"


if __name__ == "__main__":
    raise SystemExit(main())
