#!/usr/bin/env python3
"""Generate consolidated milestones from git history."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

from evolution_common import collect_months  # noqa: E402
from evolution_common import collect_window_data  # noqa: E402
from evolution_common import commit_type  # noqa: E402
from evolution_common import get_repo_root  # noqa: E402
from evolution_common import month_bounds  # noqa: E402
from evolution_common import validate_day  # noqa: E402


TYPE_PRIORITY = {
    "feat": 5,
    "refactor": 4,
    "fix": 3,
    "docs": 2,
    "chore": 1,
    "other": 0,
}


def top_highlights(non_merge_commits: list, max_items: int) -> list:
    ranked = []
    for commit in non_merge_commits:
        typ = commit_type(commit.subject)
        ranked.append((TYPE_PRIORITY.get(typ, 0), typ, commit))
    ranked.sort(key=lambda item: (-item[0], item[2].time, item[2].hash), reverse=False)
    selected = [item for item in ranked if item[0] > 0][:max_items]
    if not selected:
        selected = ranked[:max_items]
    return selected


def build_marcos_md(month_data: list[dict], max_highlights: int) -> str:
    lines: list[str] = []
    lines.append("# Marcos De Evolucao Do Projeto")
    lines.append("")
    lines.append("Documento consolidado dos principais marcos tecnicos por mes.")
    lines.append("")
    lines.append("Atualize com:")
    lines.append("")
    lines.append("python scripts/evolution/generate_milestones.py")
    lines.append("")
    lines.append("Ou gere tudo de uma vez:")
    lines.append("")
    lines.append("python scripts/evolution/run_all.py")
    lines.append("")
    lines.append("## Timeline De Marcos")
    lines.append("")
    lines.append("| mes | total commits | no merges | merges | volume (+/-) | evidencia |")
    lines.append("|---|---:|---:|---:|---:|---|")
    for item in month_data:
        lines.append(
            f"| {item['month']} | {item['total_commits']} | {item['total_non_merges']} | "
            f"{item['total_merges']} | +{item['insertions']}/-{item['deletions']} | "
            f"[relatorio mensal](../evolucao_mensal/{item['month']}.md) |"
        )
    lines.append("")

    for item in month_data:
        lines.append(f"## Marco {item['month']}")
        lines.append("")
        lines.append("### Indicadores")
        lines.append("")
        lines.append(f"- total de commits: {item['total_commits']}")
        lines.append(f"- commits de trabalho: {item['total_non_merges']}")
        lines.append(f"- commits de integracao: {item['total_merges']}")
        lines.append(f"- volume sem merge: +{item['insertions']} / -{item['deletions']}")
        lines.append(f"- arquivos unicos alterados sem merge: {item['changed_files_count']}")
        lines.append("")

        lines.append("### Entregas Em Destaque")
        lines.append("")
        highlights = top_highlights(item["non_merge_commits"], max_highlights)
        if highlights:
            for score, typ, commit in highlights:
                _ = score
                lines.append(
                    f"- [{typ}] {commit.subject} ({commit.hash[:7]}) em {commit.time}"
                )
        else:
            lines.append("- Sem destaques identificados automaticamente.")
        lines.append("")

        lines.append("### Evidencias")
        lines.append("")
        lines.append(f"- Relatorio mensal: [../evolucao_mensal/{item['month']}.md](../evolucao_mensal/{item['month']}.md)")
        lines.append("")

    lines.append("## Proximos Marcos Sugeridos")
    lines.append("")
    lines.append("1. Fortalecer automacao de testes e quality gates.")
    lines.append("2. Consolidar pipeline ETL incremental com monitoracao.")
    lines.append("3. Publicar demonstracoes analiticas e dashboard final.")
    lines.append("")
    return "\n".join(lines)


def build_readme_md() -> str:
    return "\n".join(
        [
            "# Evolucao Por Marcos",
            "",
            "Consolidado de marcos tecnicos do projeto.",
            "",
            "- Arquivo principal: [MARCOS.md](MARCOS.md)",
            "",
            "Atualize com:",
            "",
            "python scripts/evolution/generate_milestones.py",
            "",
            "Ou gere tudo de uma vez:",
            "",
            "python scripts/evolution/run_all.py",
            "",
        ]
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera consolidado de marcos por mes.")
    parser.add_argument("--since", help="Data inicial YYYY-MM-DD (opcional).")
    parser.add_argument("--until", help="Data final YYYY-MM-DD (opcional).")
    parser.add_argument(
        "--max-highlights",
        type=int,
        default=6,
        help="Quantidade maxima de destaques por marco (default: 6).",
    )
    parser.add_argument("--output-dir", default="docs/evolucao_marcos", help="Diretorio de saida relativo ao root.")
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
            mode="full",
            output_dir=output_dir,
            since=args.since,
            until=args.until,
        )
        month_data: list[dict] = []
        for month in sorted(months, reverse=True):
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
            data["month"] = month
            month_data.append(data)

        marcos_md = build_marcos_md(month_data, args.max_highlights)
        (output_dir / "MARCOS.md").write_text(marcos_md, encoding="utf-8")
        (output_dir / "README.md").write_text(build_readme_md(), encoding="utf-8")

        print(f"Marcos gerados em: {output_dir}")
        print(f"Meses consolidados: {len(month_data)}")
        return 0
    except Exception as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
