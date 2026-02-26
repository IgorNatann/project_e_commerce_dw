#!/usr/bin/env python3
"""Generate daily evolution reports from git history."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

from evolution_common import collect_days  # noqa: E402
from evolution_common import collect_window_data  # noqa: E402
from evolution_common import day_bounds  # noqa: E402
from evolution_common import get_repo_root  # noqa: E402
from evolution_common import validate_day  # noqa: E402

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@dataclass(frozen=True)
class DaySummary:
    date: str
    total_commits: int
    non_merge_commits: int
    merge_commits: int


def parse_summary_from_report(path: Path) -> DaySummary | None:
    total = None
    non_merges = None
    merges = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("- total de commits: "):
            total = int(line.split(": ", 1)[1])
        elif line.startswith("- commits de trabalho (--no-merges): "):
            non_merges = int(line.split(": ", 1)[1])
        elif line.startswith("- commits de integracao (--merges): "):
            merges = int(line.split(": ", 1)[1])
    if total is None or non_merges is None or merges is None:
        return None
    if not DATE_RE.match(path.stem):
        return None
    return DaySummary(
        date=path.stem,
        total_commits=total,
        non_merge_commits=non_merges,
        merge_commits=merges,
    )


def to_markdown_report(day: str, day_data: dict) -> str:
    lines: list[str] = []
    lines.append(f"# Relatorio de Evolucao - {day}")
    lines.append("")
    lines.append("## Resumo")
    lines.append("")
    lines.append(f"- total de commits: {day_data['total_commits']}")
    lines.append(f"- commits de trabalho (--no-merges): {day_data['total_non_merges']}")
    lines.append(f"- commits de integracao (--merges): {day_data['total_merges']}")

    if day_data["first_commit"]:
        first_parts = day_data["first_commit"].split("|", 2)
        if len(first_parts) == 3:
            lines.append(f"- primeiro commit do dia: {first_parts[0]} ({first_parts[1]})")
    if day_data["last_commit"]:
        last_parts = day_data["last_commit"].split("|", 2)
        if len(last_parts) == 3:
            lines.append(f"- ultimo commit do dia: {last_parts[0]} ({last_parts[1]})")
    lines.append(f"- volume de codigo sem merge: +{day_data['insertions']} / -{day_data['deletions']}")
    lines.append(f"- arquivos unicos alterados sem merge: {day_data['changed_files_count']}")
    lines.append("")

    lines.append("## Autores")
    lines.append("")
    if day_data["authors"]:
        for commits, author in day_data["authors"]:
            lines.append(f"- {author}: {commits} commit(s)")
    else:
        lines.append("- sem autores identificados no periodo")
    lines.append("")

    lines.append("## Areas Tocadas (arquivos unicos, sem merge)")
    lines.append("")
    if day_data["areas"]:
        lines.append("| area | arquivos |")
        lines.append("|---|---:|")
        for area, count in day_data["areas"]:
            lines.append(f"| {area} | {count} |")
    else:
        lines.append("Sem alteracoes de trabalho no dia.")
    lines.append("")

    lines.append("## Tipos De Commit (sem merge)")
    lines.append("")
    if day_data["types"]:
        lines.append("| tipo | total |")
        lines.append("|---|---:|")
        for typ, count in day_data["types"]:
            lines.append(f"| {typ} | {count} |")
    else:
        lines.append("Sem commits de trabalho no dia.")
    lines.append("")

    lines.append("## Commits De Trabalho")
    lines.append("")
    if day_data["non_merge_commits"]:
        lines.append("| hora | hash | autor | mensagem |")
        lines.append("|---|---|---|---|")
        for commit in day_data["non_merge_commits"]:
            lines.append(
                f"| {commit.time} | {commit.hash[:7]} | {commit.author.replace('|', '/')} "
                f"| {commit.subject.replace('|', '/')} |"
            )
    else:
        lines.append("Sem commits de trabalho no dia.")
    lines.append("")

    lines.append("## Commits De Integracao")
    lines.append("")
    if day_data["merge_commits"]:
        lines.append("| hora | hash | autor | mensagem |")
        lines.append("|---|---|---|---|")
        for commit in day_data["merge_commits"]:
            lines.append(
                f"| {commit.time} | {commit.hash[:7]} | {commit.author.replace('|', '/')} "
                f"| {commit.subject.replace('|', '/')} |"
            )
    else:
        lines.append("Sem commits de integracao no dia.")

    return "\n".join(lines) + "\n"


def write_reports(repo_root: Path, output_dir: Path, dates: Iterable[str]) -> int:
    processed = 0
    for day in sorted(dates):
        since, until = day_bounds(day)
        data = collect_window_data(
            repo_root=repo_root,
            since_ts=since,
            until_ts=until,
            time_format="%H:%M:%S",
            first_last_format="%H:%M:%S",
        )
        if not data:
            continue
        content = to_markdown_report(day, data)
        (output_dir / f"{day}.md").write_text(content, encoding="utf-8")
        processed += 1
    return processed


def rebuild_index_readme(output_dir: Path) -> None:
    summaries: list[DaySummary] = []
    for path in sorted(output_dir.glob("*.md")):
        if path.name in {"README.md", "SOBRE_GERADOR.md"}:
            continue
        parsed = parse_summary_from_report(path)
        if parsed:
            summaries.append(parsed)
    summaries.sort(key=lambda item: item.date, reverse=True)

    lines = [
        "# Evolucao Diaria Do Projeto",
        "",
        "Relatorios diarios gerados a partir do historico Git do repositorio.",
        "",
        "Guia do gerador: [SOBRE_GERADOR.md](SOBRE_GERADOR.md)",
        "",
        "## Como Atualizar",
        "",
        "Diario incremental (recomendado para uso diario):",
        "",
        "python scripts/evolution/generate_daily_reports.py",
        "",
        "Diario full (reprocessa todo o historico):",
        "",
        "python scripts/evolution/generate_daily_reports.py --mode full",
        "",
        "Gerar tudo (diario + mensal + marcos):",
        "",
        "python scripts/evolution/run_all.py",
        "",
        "## Indice De Dias",
        "",
        "| data | total commits | no merges | merges | relatorio |",
        "|---|---:|---:|---:|---|",
    ]
    for item in summaries:
        lines.append(
            f"| {item.date} | {item.total_commits} | {item.non_merge_commits} "
            f"| {item.merge_commits} | [abrir]({item.date}.md) |"
        )
    (output_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera relatorios diarios de evolucao do projeto.")
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="full: reprocessa todo historico; incremental: ultimo dia + novos dias.",
    )
    parser.add_argument("--since", help="Data inicial no formato YYYY-MM-DD (opcional).")
    parser.add_argument("--until", help="Data final no formato YYYY-MM-DD (opcional).")
    parser.add_argument("--output-dir", default="docs/evolucao_diaria", help="Diretorio de saida relativo ao root.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_day(args.since, "--since")
        validate_day(args.until, "--until")
        repo_root = get_repo_root()
        output_dir = (repo_root / args.output_dir).resolve()
        output_dir.mkdir(parents=True, exist_ok=True)

        days = collect_days(
            repo_root=repo_root,
            mode=args.mode,
            output_dir=output_dir,
            since=args.since,
            until=args.until,
        )
        processed = write_reports(repo_root, output_dir, days)
        rebuild_index_readme(output_dir)
        print(f"Relatorios diarios gerados em: {output_dir}")
        print(f"Dias processados nesta execucao: {processed}")
        print(f"Modo: {args.mode}")
        return 0
    except Exception as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
