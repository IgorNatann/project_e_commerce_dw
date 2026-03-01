#!/usr/bin/env python3
"""Runner de alertas externos para falha ETL e atraso de SLA."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

try:
    import pyodbc  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    pyodbc = None


@dataclass(frozen=True)
class AlertSettings:
    enabled: bool
    provider: str
    discord_webhook_url: str
    run_once: bool
    check_interval_seconds: int
    cooldown_minutes: int
    sla_watermark_delay_minutes: int
    sla_no_run_hours: int
    fail_rate_threshold: float
    fail_rate_min_runs: int
    timezone_name: str
    state_file: Path
    http_timeout_seconds: int
    command_timeout_seconds: int
    dw_conn_str: str

    @classmethod
    def from_env(cls) -> "AlertSettings":
        timezone_name = os.getenv("ALERT_TIMEZONE", "America/Sao_Paulo").strip() or "America/Sao_Paulo"
        state_file = Path(os.getenv("ALERT_STATE_FILE", "/var/lib/etl-alerts/state.json"))
        return cls(
            enabled=_to_bool(os.getenv("ALERT_ENABLED", "false")),
            provider=(os.getenv("ALERT_PROVIDER", "discord").strip().lower() or "discord"),
            discord_webhook_url=os.getenv("ALERT_DISCORD_WEBHOOK_URL", "").strip(),
            run_once=_to_bool(os.getenv("ALERT_RUN_ONCE", "false")),
            check_interval_seconds=max(30, _to_int(os.getenv("ALERT_CHECK_INTERVAL_SECONDS"), 300)),
            cooldown_minutes=max(1, _to_int(os.getenv("ALERT_COOLDOWN_MINUTES"), 30)),
            sla_watermark_delay_minutes=max(5, _to_int(os.getenv("ALERT_SLA_WATERMARK_DELAY_MINUTES"), 120)),
            sla_no_run_hours=max(1, _to_int(os.getenv("ALERT_SLA_NO_RUN_HOURS"), 24)),
            fail_rate_threshold=_to_float(os.getenv("ALERT_FAIL_RATE_THRESHOLD"), 0.30),
            fail_rate_min_runs=max(1, _to_int(os.getenv("ALERT_FAIL_RATE_MIN_RUNS"), 3)),
            timezone_name=timezone_name,
            state_file=state_file,
            http_timeout_seconds=max(3, _to_int(os.getenv("ALERT_HTTP_TIMEOUT_SECONDS"), 15)),
            command_timeout_seconds=max(30, _to_int(os.getenv("ETL_SQL_TIMEOUT_SECONDS"), 120)),
            dw_conn_str=_build_dw_conn_str(),
        )


def _to_bool(raw_value: str | None) -> bool:
    if raw_value is None:
        return False
    return raw_value.strip().lower() in {"1", "true", "t", "yes", "y", "on"}


def _to_int(raw_value: str | None, default: int) -> int:
    if raw_value is None:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default


def _to_float(raw_value: str | None, default: float) -> float:
    if raw_value is None:
        return default
    try:
        return float(raw_value)
    except ValueError:
        return default


def _resolve_sql_driver() -> str:
    explicit_driver = os.getenv("ETL_SQL_DRIVER")
    if explicit_driver:
        return explicit_driver

    installed_drivers: list[str] = []
    if pyodbc is not None:
        try:
            installed_drivers = list(pyodbc.drivers())
        except Exception:  # noqa: BLE001
            installed_drivers = []

    for candidate in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"):
        if candidate in installed_drivers:
            return candidate
    return "ODBC Driver 18 for SQL Server"


def _build_dw_conn_str() -> str:
    driver = _resolve_sql_driver()
    server = os.getenv("ETL_SQL_SERVER", "sqlserver")
    port = os.getenv("ETL_SQL_PORT", "").strip()
    database = os.getenv("ETL_DW_DB", "DW_ECOMMERCE")
    user = os.getenv("ETL_SQL_USER", "etl_monitor")
    password = os.getenv("ETL_SQL_PASSWORD", "")
    encrypt = os.getenv("ETL_SQL_ENCRYPT", "yes")
    trust_server_certificate = os.getenv("ETL_SQL_TRUST_SERVER_CERTIFICATE", "yes")

    if not password:
        raise ValueError("Variavel ETL_SQL_PASSWORD nao definida.")

    server_part = f"{server},{port}" if port else server
    return (
        f"Driver={{{driver}}};"
        f"Server={server_part};"
        f"Database={database};"
        f"UID={user};"
        f"PWD={password};"
        f"Encrypt={encrypt};"
        f"TrustServerCertificate={trust_server_certificate};"
    )


def _connect_dw(settings: AlertSettings):
    if pyodbc is None:
        raise ModuleNotFoundError("Dependencia ausente: pyodbc.")
    connection = pyodbc.connect(settings.dw_conn_str, autocommit=True)
    connection.timeout = settings.command_timeout_seconds
    return connection


def _query_all(connection: Any, sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    cursor = connection.cursor()
    try:
        cursor.execute(sql, params)
        columns = [col[0] for col in cursor.description or []]
        rows = cursor.fetchall()
        return [dict(zip(columns, row)) for row in rows]
    finally:
        cursor.close()


def _query_active_entities(connection: Any) -> list[dict[str, Any]]:
    query = """
    ;WITH latest_entity AS
    (
        SELECT
            re.entity_name,
            re.status AS entity_last_status,
            re.entity_started_at,
            re.entity_finished_at,
            re.error_message,
            ROW_NUMBER() OVER (
                PARTITION BY re.entity_name
                ORDER BY ISNULL(re.entity_finished_at, re.entity_started_at) DESC, re.run_entity_id DESC
            ) AS rn
        FROM audit.etl_run_entity AS re
    )
    SELECT
        c.entity_name,
        c.last_status AS control_last_status,
        c.last_success_at,
        c.watermark_updated_at,
        le.entity_last_status,
        le.entity_started_at,
        le.entity_finished_at,
        le.error_message,
        COALESCE(fr.total_runs_7d, 0) AS total_runs_7d,
        COALESCE(fr.failed_runs_7d, 0) AS failed_runs_7d,
        COALESCE(fr.fail_rate_7d, 0.0) AS fail_rate_7d
    FROM ctl.etl_control AS c
    LEFT JOIN latest_entity AS le
        ON le.entity_name = c.entity_name
       AND le.rn = 1
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS total_runs_7d,
            SUM(CASE WHEN re.status = 'failed' THEN 1 ELSE 0 END) AS failed_runs_7d,
            CAST(
                1.0 * SUM(CASE WHEN re.status = 'failed' THEN 1 ELSE 0 END)
                / NULLIF(COUNT(*), 0) AS decimal(12, 4)
            ) AS fail_rate_7d
        FROM audit.etl_run_entity AS re
        WHERE re.entity_name = c.entity_name
          AND re.entity_started_at >= DATEADD(DAY, -7, SYSUTCDATETIME())
    ) AS fr
    WHERE c.is_active = 1
    ORDER BY c.entity_name;
    """
    return _query_all(connection, query)


def _as_utc(dt: Any) -> datetime | None:
    if not isinstance(dt, datetime):
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _safe_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value)


def _truncate(value: str, limit: int = 220) -> str:
    text = " ".join(value.split())
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def _evaluate_entity_alerts(
    row: dict[str, Any],
    settings: AlertSettings,
    now_utc: datetime,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    entity_name = _safe_str(row.get("entity_name"), "(desconhecida)")

    control_last_status = _safe_str(row.get("control_last_status")).lower()
    entity_last_status = _safe_str(row.get("entity_last_status")).lower()
    error_message = _truncate(_safe_str(row.get("error_message")), 220)

    last_success_at = _as_utc(row.get("last_success_at"))
    watermark_updated_at = _as_utc(row.get("watermark_updated_at"))
    last_entity_started_at = _as_utc(row.get("entity_started_at"))
    last_entity_finished_at = _as_utc(row.get("entity_finished_at"))
    run_reference = last_entity_finished_at or last_entity_started_at
    freshness_reference = watermark_updated_at or last_success_at or run_reference

    if control_last_status == "failed" or entity_last_status == "failed":
        findings.append(
            {
                "key": f"{entity_name}|etl_failure",
                "entity_name": entity_name,
                "alert_type": "etl_failure",
                "severity": "ALERTA",
                "title": "Falha ETL detectada",
                "detail": (
                    f"Ultimo status controle={control_last_status or '-'} "
                    f"entidade={entity_last_status or '-'}; erro={error_message or '(sem mensagem)'}"
                ),
            }
        )

    if freshness_reference is not None:
        delay_minutes = int((now_utc - freshness_reference).total_seconds() // 60)
        if delay_minutes > settings.sla_watermark_delay_minutes:
            findings.append(
                {
                    "key": f"{entity_name}|sla_watermark_delay",
                    "entity_name": entity_name,
                    "alert_type": "sla_watermark_delay",
                    "severity": "ATENCAO",
                    "title": "Atraso de SLA por watermark",
                    "detail": (
                        f"Sem atualizacao ha {delay_minutes} minutos "
                        f"(limite={settings.sla_watermark_delay_minutes} min)."
                    ),
                }
            )

    if run_reference is None:
        findings.append(
            {
                "key": f"{entity_name}|sla_no_recent_run",
                "entity_name": entity_name,
                "alert_type": "sla_no_recent_run",
                "severity": "ATENCAO",
                "title": "Sem execucao recente",
                "detail": "Nao existe run registrada para a entidade no audit.etl_run_entity.",
            }
        )
    else:
        delay_hours = int((now_utc - run_reference).total_seconds() // 3600)
        if delay_hours > settings.sla_no_run_hours:
            findings.append(
                {
                    "key": f"{entity_name}|sla_no_recent_run",
                    "entity_name": entity_name,
                    "alert_type": "sla_no_recent_run",
                    "severity": "ATENCAO",
                    "title": "Sem execucao recente",
                    "detail": (
                        f"Ultima execucao ha {delay_hours} horas "
                        f"(limite={settings.sla_no_run_hours} h)."
                    ),
                }
            )

    total_runs_7d = _to_int(_safe_str(row.get("total_runs_7d"), "0"), 0)
    failed_runs_7d = _to_int(_safe_str(row.get("failed_runs_7d"), "0"), 0)
    fail_rate_7d = _to_float(_safe_str(row.get("fail_rate_7d"), "0"), 0.0)

    if total_runs_7d >= settings.fail_rate_min_runs and fail_rate_7d >= settings.fail_rate_threshold:
        findings.append(
            {
                "key": f"{entity_name}|etl_recurrent_failure",
                "entity_name": entity_name,
                "alert_type": "etl_recurrent_failure",
                "severity": "ATENCAO",
                "title": "Falha recorrente ETL (7 dias)",
                "detail": (
                    f"Taxa de falha={fail_rate_7d * 100:.1f}% "
                    f"({failed_runs_7d}/{total_runs_7d}); "
                    f"limite={settings.fail_rate_threshold * 100:.1f}%."
                ),
            }
        )

    return findings


def _ensure_state_dir(state_file: Path) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)


def _load_state(state_file: Path) -> dict[str, Any]:
    if not state_file.exists():
        return {"version": 1, "alerts": {}}
    try:
        payload = json.loads(state_file.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            return {"version": 1, "alerts": {}}
        alerts = payload.get("alerts")
        if not isinstance(alerts, dict):
            payload["alerts"] = {}
        return payload
    except Exception:  # noqa: BLE001
        return {"version": 1, "alerts": {}}


def _save_state(state_file: Path, state: dict[str, Any]) -> None:
    state_file.write_text(json.dumps(state, ensure_ascii=True, indent=2), encoding="utf-8")


def _parse_iso_utc(raw_value: Any) -> datetime | None:
    if not raw_value:
        return None
    try:
        dt = datetime.fromisoformat(str(raw_value))
    except ValueError:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _get_local_time_str(settings: AlertSettings, dt_utc: datetime) -> str:
    try:
        zone = ZoneInfo(settings.timezone_name)
    except Exception:  # noqa: BLE001
        zone = ZoneInfo("UTC")
    return dt_utc.astimezone(zone).strftime("%Y-%m-%d %H:%M:%S")


def _build_discord_payload(
    settings: AlertSettings,
    event_kind: str,
    finding: dict[str, Any],
    now_utc: datetime,
) -> dict[str, Any]:
    severity = _safe_str(finding.get("severity"), "ATENCAO").upper()
    entity_name = _safe_str(finding.get("entity_name"), "(desconhecida)")
    title = _safe_str(finding.get("title"), "Alerta ETL")
    detail = _safe_str(finding.get("detail"), "")
    local_time = _get_local_time_str(settings, now_utc)

    if event_kind == "RESOLVIDO":
        embed_color = 3066993
        prefix = "RESOLVIDO"
    elif severity == "ALERTA":
        embed_color = 15158332
        prefix = "ALERTA"
    else:
        embed_color = 16753920
        prefix = "ATENCAO"

    return {
        "content": f"[{prefix}] DW E-commerce | {entity_name}",
        "embeds": [
            {
                "title": title,
                "description": detail or "Sem detalhe adicional.",
                "color": embed_color,
                "timestamp": now_utc.isoformat(),
                "fields": [
                    {"name": "Entidade", "value": entity_name, "inline": True},
                    {"name": "Tipo", "value": _safe_str(finding.get("alert_type"), "-"), "inline": True},
                    {"name": "Horario", "value": f"{local_time} ({settings.timezone_name})", "inline": False},
                ],
            }
        ],
    }


def _send_discord(settings: AlertSettings, payload: dict[str, Any]) -> tuple[bool, str]:
    if not settings.discord_webhook_url:
        return False, "ALERT_DISCORD_WEBHOOK_URL nao configurado."

    body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
    request = urllib.request.Request(
        url=settings.discord_webhook_url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=settings.http_timeout_seconds) as response:
            status_code = int(getattr(response, "status", 0) or 0)
        if status_code in (200, 204):
            return True, "ok"
        return False, f"status_http={status_code}"
    except urllib.error.HTTPError as exc:
        return False, f"http_error={exc.code}"
    except Exception as exc:  # noqa: BLE001
        return False, f"erro={exc}"


def _send_event(
    settings: AlertSettings,
    event_kind: str,
    finding: dict[str, Any],
    now_utc: datetime,
) -> bool:
    if not settings.enabled:
        return False

    if settings.provider != "discord":
        print(f"[alert-runner] provider nao suportado: {settings.provider}")
        return False

    payload = _build_discord_payload(settings, event_kind, finding, now_utc)
    ok, detail = _send_discord(settings, payload)
    print(
        f"[alert-runner] envio {event_kind} "
        f"{_safe_str(finding.get('key'))} -> {'OK' if ok else 'FAIL'} ({detail})"
    )
    return ok


def _process_alerts(
    settings: AlertSettings,
    findings: list[dict[str, Any]],
    now_utc: datetime,
) -> None:
    _ensure_state_dir(settings.state_file)
    state = _load_state(settings.state_file)
    alerts_state: dict[str, dict[str, Any]] = state.get("alerts", {})
    if not isinstance(alerts_state, dict):
        alerts_state = {}

    cooldown_seconds = settings.cooldown_minutes * 60
    findings_by_key = {finding["key"]: finding for finding in findings}

    for key, finding in findings_by_key.items():
        previous = alerts_state.get(key, {})
        previous_status = _safe_str(previous.get("status"), "resolved")
        previous_sent_at = _parse_iso_utc(previous.get("last_sent_at"))

        should_send = False
        event_kind = "ALERTA"

        if previous_status != "firing":
            should_send = True
        elif previous_sent_at is None:
            should_send = True
            event_kind = "ALERTA"
        else:
            elapsed = (now_utc - previous_sent_at).total_seconds()
            if elapsed >= cooldown_seconds:
                should_send = True
                event_kind = "ALERTA_REPETICAO"

        sent_ok = True
        if should_send:
            sent_ok = _send_event(settings, event_kind, finding, now_utc)

        alerts_state[key] = {
            "status": "firing",
            "last_sent_at": now_utc.isoformat() if (should_send and sent_ok) else previous.get("last_sent_at"),
            "last_seen_at": now_utc.isoformat(),
            "entity_name": finding.get("entity_name"),
            "alert_type": finding.get("alert_type"),
            "severity": finding.get("severity"),
            "title": finding.get("title"),
            "detail": finding.get("detail"),
        }

    keys_to_resolve = [
        key
        for key, value in alerts_state.items()
        if _safe_str(value.get("status")) == "firing" and key not in findings_by_key
    ]
    for key in keys_to_resolve:
        previous = alerts_state.get(key, {})
        resolved_finding = {
            "key": key,
            "entity_name": _safe_str(previous.get("entity_name"), key.split("|", 1)[0]),
            "alert_type": _safe_str(previous.get("alert_type"), key.split("|", 1)[-1]),
            "severity": "OK",
            "title": f"Condicao normalizada: {_safe_str(previous.get('title'), 'alerta')}",
            "detail": "A condicao de alerta voltou para estado normal.",
        }
        sent_ok = _send_event(settings, "RESOLVIDO", resolved_finding, now_utc)
        alerts_state[key] = {
            **previous,
            "status": "resolved",
            "last_seen_at": now_utc.isoformat(),
            "last_sent_at": now_utc.isoformat() if sent_ok else previous.get("last_sent_at"),
        }

    state["version"] = 1
    state["alerts"] = alerts_state
    _save_state(settings.state_file, state)


def _run_cycle(settings: AlertSettings) -> None:
    now_utc = datetime.now(timezone.utc)

    if not settings.enabled:
        print("[alert-runner] ALERT_ENABLED=false; monitorando sem envio externo.")

    connection = _connect_dw(settings)
    try:
        active_entities = _query_active_entities(connection)
    finally:
        connection.close()

    findings: list[dict[str, Any]] = []
    for row in active_entities:
        findings.extend(_evaluate_entity_alerts(row, settings, now_utc))

    print(
        f"[alert-runner] ciclo: entidades_ativas={len(active_entities)} "
        f"alertas_ativos={len(findings)}"
    )
    _process_alerts(settings, findings, now_utc)


def main() -> int:
    settings = AlertSettings.from_env()
    print(
        "[alert-runner] iniciado "
        f"(enabled={settings.enabled}, provider={settings.provider}, "
        f"interval={settings.check_interval_seconds}s, cooldown={settings.cooldown_minutes}m)"
    )

    while True:
        try:
            _run_cycle(settings)
        except Exception as exc:  # noqa: BLE001
            print(f"[alert-runner] erro no ciclo: {exc}")
            if settings.run_once:
                return 1

        if settings.run_once:
            return 0
        time.sleep(settings.check_interval_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
