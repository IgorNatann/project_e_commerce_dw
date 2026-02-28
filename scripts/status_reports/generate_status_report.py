#!/usr/bin/env python3
"""Generate daily status report files with a fixed template."""

from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore[assignment]


DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DEFAULT_TZ = "America/Sao_Paulo"
SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[2]
REPORT_DIR = REPO_ROOT / "docs" / "status_reports"
GENERATOR_CMD = "python scripts/status_reports/generate_status_report.py"


def validate_date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("Use o formato YYYY-MM-DD para --date.")
    return value


def today_str(tz_name: str) -> str:
    if ZoneInfo is None:
        return datetime.now().strftime("%Y-%m-%d")
    return datetime.now(ZoneInfo(tz_name)).strftime("%Y-%m-%d")


def report_template(report_date: str) -> str:
    lines = [
        f"# Status Report - {report_date}",
        "",
        "## Resumo Executivo",
        "",
        "- [preencher] resumo objetivo do dia em 2-4 bullets.",
        "",
        "## Entregas Concluidas",
        "",
        "- [preencher] principais entregas concluidas no periodo.",
        "",
        "## Em Andamento",
        "",
        "- [preencher] frentes ativas que seguem em execucao.",
        "",
        "## Pendencias Prioritarias",
        "",
        "- [preencher] itens com maior prioridade para destravar o objetivo.",
        "",
        "## Riscos / Bloqueios",
        "",
        "- [preencher] risco, impacto e acao de mitigacao (ou informar sem bloqueios).",
        "",
        "## Proximos Passos",
        "",
        "1. [preencher] proximo passo 1",
        "2. [preencher] proximo passo 2",
        "3. [preencher] proximo passo 3",
        "",
        "## Decisoes Necessarias",
        "",
        "- [preencher] decisoes pendentes para equipe/gestao/cliente.",
        "",
    ]
    return "\n".join(lines)


def collect_report_dates(report_dir: Path) -> Iterable[str]:
    for path in sorted(report_dir.glob("*.md")):
        if path.name == "README.md":
            continue
        if DATE_RE.match(path.stem):
            yield path.stem


def rebuild_index_readme(report_dir: Path) -> None:
    dates = sorted(collect_report_dates(report_dir), reverse=True)
    lines = [
        "# Status Reports",
        "",
        "Relatorios periodicos para equipe e cliente, com historico por data.",
        "",
        "## Como Gerar",
        "",
        "Relatorio do dia atual:",
        "",
        GENERATOR_CMD,
        "",
        "Relatorio para uma data especifica:",
        "",
        f"{GENERATOR_CMD} --date 2026-02-28",
        "",
        "Sobrescrever um relatorio existente:",
        "",
        f"{GENERATOR_CMD} --date 2026-02-28 --force",
        "",
        "## Indice",
        "",
        "| data | report |",
        "|---|---|",
    ]
    for date_value in dates:
        lines.append(f"| {date_value} | [abrir]({date_value}.md) |")

    (report_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera arquivo diario de status report com estrutura padrao."
    )
    parser.add_argument(
        "--date",
        type=validate_date,
        help="Data alvo no formato YYYY-MM-DD. Se omitido, usa hoje em America/Sao_Paulo.",
    )
    parser.add_argument(
        "--tz",
        default=DEFAULT_TZ,
        help="Timezone usada para resolver a data padrao (default: America/Sao_Paulo).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Sobrescreve o arquivo da data alvo se ele ja existir.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report_dir = REPORT_DIR
    report_dir.mkdir(parents=True, exist_ok=True)

    report_date = args.date or today_str(args.tz)
    target = report_dir / f"{report_date}.md"

    if target.exists() and not args.force:
        print(f"Arquivo ja existe: {target}")
        print("Nenhuma alteracao no report. Use --force para sobrescrever.")
    else:
        target.write_text(report_template(report_date), encoding="utf-8")
        print(f"Report gerado: {target}")

    rebuild_index_readme(report_dir)
    print(f"Indice atualizado: {report_dir / 'README.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
