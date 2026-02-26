#!/usr/bin/env python3
"""Wrapper that runs daily + monthly + milestones."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    current = Path(__file__).resolve()
    target = current.parent / "evolution" / "run_all.py"
    cmd = [sys.executable, str(target), *sys.argv[1:]]
    proc = subprocess.run(cmd, check=False)
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
