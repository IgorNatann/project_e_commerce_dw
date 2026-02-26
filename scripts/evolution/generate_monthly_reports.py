#!/usr/bin/env python3
"""Generate monthly evolution reports from git history."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

from evolution_common import collect_months  # noqa: E402
from evolution_common import collect_window_data  # noqa: E402
from evolution_common import get_repo_root  # noqa: E402
from evolution_common import month_bounds  # noqa: E402
from evolution_common import validate_day  # noqa: E402

MONTH_RE = re.compile(r"^\d{4}-\d{2}$")


@dataclass(frozen=True)
class MonthSummary:
    month: str
    total_commits: int
    non_merge_commits: int
    merge_commits: int


def parse_summary_from_report(path: Path) -> MonthSummary | None:
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
    if not MONTH_RE.match(path.stem):
        return None
    return MonthSummary(
        month=path.stem,
        total_commits=total,
        non_merge_commits=non_merges,
        merge_commits=merges,
    )


def to_markdown_report(month: str, data: dict) -> str:
    lines: list[str] = []
    lines.append(f"# Relatorio Mensal de Evolucao - {month}")
    lines.append("")
    lines.append("## Resumo")
    lines.append("")
    lines.append(f"- total de commits: {data['total_commits']}")
    lines.append(f"- commits de trabalho (--no-merges): {data['total_non_merges']}")
    lines.append(f"- commits de integracao (--merges): {data['total_merges']}")

    if data["first_commit"]:
        first_parts = data["first_commit"].split("|", 2)
        if len(first_parts) == 3:
            lines.append(f"- primeiro commit do mes: {first_parts[0]} ({first_parts[1]})")
    if data["last_commit"]:
        last_parts = data["last_commit"].split("|", 2)
        if len(last_parts) == 3:
            lines.append(f"- ultimo commit do mes: {last_parts[0]} ({last_parts[1]})")
    lines.append(f"- volume de codigo sem merge: +{data['insertions']} / -{data['deletions']}")
    lines.append(f"- arquivos unicos alterados sem merge: {data['changed_files_count']}")
    lines.append("")

    lines.append("## Distribuicao Diaria")
    lines.append("")
    day_non_merge = Counter(commit.time[:10] for commit in data["non_merge_commits"] if len(commit.time) >= 10)
    day_merge = Counter(commit.time[:10] for commit in data["merge_commits"] if len(commit.time) >= 10)
    days = sorted(set(day_non_merge.keys()) | set(day_merge.keys()))
    if days:
        lines.append("| data | no merges | merges | total |")
        lines.append("|---|---:|---:|---:|")
        for day in days:
            nm = day_non_merge.get(day, 0)
            mg = day_merge.get(day, 0)
            lines.append(f"| {day} | {nm} | {mg} | {nm + mg} |")
    else:
        lines.append("Sem distribuicao diaria disponivel.")
    lines.append("")

    lines.append("## Autores")
    lines.append("")
    if data["authors"]:
        for commits, author in data["authors"]:
            lines.append(f"- {author}: {commits} commit(s)")
    else:
        lines.append("- sem autores identificados no periodo")
    lines.append("")

    lines.append("## Areas Tocadas (arquivos unicos, sem merge)")
    lines.append("")
    if data["areas"]:
        lines.append("| area | arquivos |")
        lines.append("|---|---:|")
        for area, count in data["areas"]:
            lines.append(f"| {area} | {count} |")
    else:
        lines.append("Sem alteracoes de trabalho no mes.")
    lines.append("")

    lines.append("## Tipos De Commit (sem merge)")
    lines.append("")
    if data["types"]:
        lines.append("| tipo | total |")
        lines.append("|---|---:|")
        for typ, count in data["types"]:
            lines.append(f"| {typ} | {count} |")
    else:
        lines.append("Sem commits de trabalho no mes.")
    lines.append("")

    lines.append("## Commits De Trabalho Do Mes")
    lines.append("")
    if data["non_merge_commits"]:
        lines.append("| data_hora | hash | autor | mensagem |")
        lines.append("|---|---|---|---|")
        for commit in data["non_merge_commits"]:
            lines.append(
                f"| {commit.time} | {commit.hash[:7]} | {commit.author.replace('|', '/')} "
                f"| {commit.subject.replace('|', '/')} |"
            )
    else:
        lines.append("Sem commits de trabalho no mes.")
    lines.append("")

    lines.append("## Commits De Integracao Do Mes")
    lines.append("")
    if data["merge_commits"]:
        lines.append("| data_hora | hash | autor | mensagem |")
        lines.append("|---|---|---|---|")
        for commit in data["merge_commits"]:
            lines.append(
                f"| {commit.time} | {commit.hash[:7]} | {commit.author.replace('|', '/')} "
                f"| {commit.subject.replace('|', '/')} |"
            )
    else:
        lines.append("Sem commits de integracao no mes.")

    return "\n".join(lines) + "\n"


def write_reports(repo_root: Path, output_dir: Path, months: Iterable[str]) -> int:
    processed = 0
    for month in sorted(months):
        since, until = month_bounds(month)
        data = collect_window_data(
            repo_root=repo_root,
            since_ts=since,
            until_ts=until,
            time_format="%Y-%m-%d %H:%M:%S",
            first_last_format="%Y-%m-%d %H:%M:%S",
        )
        if not data:
            continue
        content = to_markdown_report(month, data)
        (output_dir / f"{month}.md").write_text(content, encoding="utf-8")
        processed += 1
    return processed


def rebuild_index_readme(output_dir: Path) -> None:
    summaries: list[MonthSummary] = []
    for path in sorted(output_dir.glob("*.md")):
        if path.name == "README.md":
            continue
        parsed = parse_summary_from_report(path)
        if parsed:
            summaries.append(parsed)
    summaries.sort(key=lambda item: item.month, reverse=True)

    lines = [
        "# Evolucao Mensal Do Projeto",
        "",
        "Relatorios mensais gerados a partir do historico Git.",
        "",
        "## Como Atualizar",
        "",
        "Mensal incremental (recomendado):",
        "",
        "python scripts/evolution/generate_monthly_reports.py",
        "",
        "Mensal full:",
        "",
        "python scripts/evolution/generate_monthly_reports.py --mode full",
        "",
        "Gerar tudo (diario + mensal + marcos):",
        "",
        "python scripts/evolution/run_all.py",
        "",
        "## Indice De Meses",
        "",
        "| mes | total commits | no merges | merges | relatorio |",
        "|---|---:|---:|---:|---|",
    ]
    for item in summaries:
        lines.append(
            f"| {item.month} | {item.total_commits} | {item.non_merge_commits} "
            f"| {item.merge_commits} | [abrir]({item.month}.md) |"
        )
    (output_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera relatorios mensais de evolucao do projeto.")
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="full: reprocessa todo historico; incremental: ultimo mes + novos meses.",
    )
    parser.add_argument("--since", help="Data inicial YYYY-MM-DD (opcional).")
    parser.add_argument("--until", help="Data final YYYY-MM-DD (opcional).")
    parser.add_argument("--output-dir", default="docs/evolucao_mensal", help="Diretorio de saida relativo ao root.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_day(args.since, "--since")
        validate_day(args.until, "--until")
        repo_root = get_repo_root()
        output_dir = (repo_root / args.output_dir).resolve()
        output_dir.mkdir(parents=True, exist_ok=True)

        months = collect_months(
            repo_root=repo_root,
            mode=args.mode,
            output_dir=output_dir,
            since=args.since,
            until=args.until,
        )
        processed = write_reports(repo_root, output_dir, months)
        rebuild_index_readme(output_dir)
        print(f"Relatorios mensais gerados em: {output_dir}")
        print(f"Meses processados nesta execucao: {processed}")
        print(f"Modo: {args.mode}")
        return 0
    except Exception as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
