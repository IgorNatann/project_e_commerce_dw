#!/usr/bin/env python3
"""Run daily, monthly and milestone generators in sequence."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent


def run_command(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=CURRENT_DIR.parent.parent, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"Falha ao executar: {' '.join(cmd)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Executa diario + mensal + marcos em sequencia.")
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="Modo aplicado nos geradores diario e mensal.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        py = sys.executable
        daily = str(CURRENT_DIR / "generate_daily_reports.py")
        monthly = str(CURRENT_DIR / "generate_monthly_reports.py")
        milestones = str(CURRENT_DIR / "generate_milestones.py")

        run_command([py, daily, "--mode", args.mode])
        run_command([py, monthly, "--mode", args.mode])
        run_command([py, milestones])

        print("Processo completo finalizado: diario + mensal + marcos.")
        return 0
    except Exception as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
