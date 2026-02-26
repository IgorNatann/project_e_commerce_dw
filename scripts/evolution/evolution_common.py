#!/usr/bin/env python3
"""Shared utilities for evolution report generators."""

from __future__ import annotations

import re
import subprocess
import unicodedata
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

DELIM = "\x1f"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MONTH_RE = re.compile(r"^\d{4}-\d{2}$")
NUMSTAT_RE = re.compile(r"^(\d+|-)\s+(\d+|-)\s+(.+)$")


@dataclass(frozen=True)
class Commit:
    hash: str
    author: str
    time: str
    subject: str


def run_git(repo_root: Path, *args: str) -> list[str]:
    cmd = ["git", "-c", "i18n.logOutputEncoding=utf-8", *args]
    proc = subprocess.run(
        cmd,
        cwd=repo_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip() or "<no stderr>"
        raise RuntimeError(f"git command failed: {' '.join(cmd)}\n{stderr}")
    if not proc.stdout:
        return []
    return proc.stdout.splitlines()


def get_repo_root() -> Path:
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip() or "<no stderr>"
        raise RuntimeError(f"Nao foi possivel identificar o root do repositorio git.\n{stderr}")
    return Path(proc.stdout.strip()).resolve()


def normalize_ascii(text: str) -> str:
    if not text:
        return ""
    normalized = unicodedata.normalize("NFKD", text)
    chars: list[str] = []
    for ch in normalized:
        if unicodedata.category(ch) == "Mn":
            continue
        if ord(ch) <= 127:
            chars.append(ch)
    return re.sub(r"\s+", " ", "".join(chars)).strip()


def parse_commit_line(line: str) -> Commit | None:
    parts = line.split(DELIM, 3)
    if len(parts) != 4:
        return None
    return Commit(
        hash=parts[0],
        author=normalize_ascii(parts[1]),
        time=parts[2],
        subject=normalize_ascii(parts[3]),
    )


def parse_shortlog_line(line: str) -> tuple[int, str] | None:
    trimmed = line.strip()
    match = re.match(r"^(\d+)\s+(.+?)\s+<.+>$", trimmed)
    if not match:
        return None
    commits = int(match.group(1))
    author = normalize_ascii(match.group(2))
    return commits, author


def root_from_path(path_value: str) -> str:
    clean = re.sub(r"\{[^}]*=>\s*", "", path_value).replace("}", "")
    parts = clean.split("/")
    return parts[0] if parts and parts[0] else "(root)"


def commit_type(subject: str) -> str:
    match = re.match(r"^([A-Za-z]+)\(", subject)
    if match:
        return match.group(1).lower()
    match = re.match(r"^([A-Za-z]+):", subject)
    if match:
        return match.group(1).lower()
    return "other"


def validate_day(day: str | None, field: str) -> None:
    if day is None:
        return
    if not DATE_RE.match(day):
        raise ValueError(f"{field} invalido: {day}. Use YYYY-MM-DD.")


def month_bounds(month: str) -> tuple[str, str]:
    return f"{month}-01 00:00:00", f"{month}-31 23:59:59"


def day_bounds(day: str) -> tuple[str, str]:
    return f"{day} 00:00:00", f"{day} 23:59:59"


def existing_stems(output_dir: Path, regex: re.Pattern[str]) -> list[str]:
    if not output_dir.exists():
        return []
    values = [
        path.stem
        for path in output_dir.glob("*.md")
        if path.is_file() and regex.match(path.stem)
    ]
    return sorted(values)


def collect_days(
    repo_root: Path,
    mode: str,
    output_dir: Path,
    since: str | None,
    until: str | None,
) -> list[str]:
    args = ["log", "--date=short", "--pretty=format:%ad"]
    effective_since = since
    if mode == "incremental" and effective_since is None:
        existing = existing_stems(output_dir, DATE_RE)
        if existing:
            effective_since = existing[-1]
    if effective_since:
        args.append(f"--since={effective_since} 00:00:00")
    if until:
        args.append(f"--until={until} 23:59:59")
    values = sorted(set(run_git(repo_root, *args)))
    return [day for day in values if DATE_RE.match(day)]


def collect_months(
    repo_root: Path,
    mode: str,
    output_dir: Path,
    since: str | None,
    until: str | None,
) -> list[str]:
    args = ["log", "--date=format:%Y-%m", "--pretty=format:%ad"]
    effective_since = since
    if mode == "incremental" and effective_since is None:
        existing = existing_stems(output_dir, MONTH_RE)
        if existing:
            effective_since = f"{existing[-1]}-01"
    if effective_since:
        args.append(f"--since={effective_since} 00:00:00")
    if until:
        args.append(f"--until={until} 23:59:59")
    values = sorted(set(run_git(repo_root, *args)))
    return [month for month in values if MONTH_RE.match(month)]


def collect_window_data(
    repo_root: Path,
    since_ts: str,
    until_ts: str,
    time_format: str,
    first_last_format: str,
) -> dict | None:
    all_raw = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        "--pretty=format:%H%x1f%an%x1f%ad%x1f%s",
        f"--date=format:{time_format}",
    )
    if not all_raw:
        return None

    non_merge_raw = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        "--no-merges",
        "--pretty=format:%H%x1f%an%x1f%ad%x1f%s",
        f"--date=format:{time_format}",
    )
    merge_raw = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        "--merges",
        "--pretty=format:%H%x1f%an%x1f%ad%x1f%s",
        f"--date=format:{time_format}",
    )

    all_commits = [c for c in (parse_commit_line(row) for row in all_raw) if c]
    non_merge_commits = [c for c in (parse_commit_line(row) for row in non_merge_raw) if c]
    merge_commits = [c for c in (parse_commit_line(row) for row in merge_raw) if c]

    first_row = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        f"--date=format:{first_last_format}",
        "--reverse",
        "--pretty=format:%ad|%h|%s",
    )
    last_row = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        f"--date=format:{first_last_format}",
        "--pretty=format:%ad|%h|%s",
    )
    first_commit = first_row[0] if first_row else ""
    last_commit = last_row[0] if last_row else ""

    insertions = 0
    deletions = 0
    numstat_rows = run_git(
        repo_root,
        "log",
        f"--since={since_ts}",
        f"--until={until_ts}",
        "--no-merges",
        "--numstat",
        "--pretty=tformat:",
    )
    for row in numstat_rows:
        match = NUMSTAT_RE.match(row)
        if not match:
            continue
        added = match.group(1)
        removed = match.group(2)
        if added != "-":
            insertions += int(added)
        if removed != "-":
            deletions += int(removed)

    changed_files = sorted(
        {
            row
            for row in run_git(
                repo_root,
                "log",
                f"--since={since_ts}",
                f"--until={until_ts}",
                "--no-merges",
                "--name-only",
                "--pretty=format:",
            )
            if row.strip()
        }
    )
    areas = Counter(root_from_path(path) for path in changed_files)
    types = Counter(commit_type(commit.subject) for commit in non_merge_commits)

    authors: list[tuple[int, str]] = []
    for row in run_git(
        repo_root,
        "shortlog",
        "-sne",
        "HEAD",
        f"--since={since_ts}",
        f"--until={until_ts}",
    ):
        parsed = parse_shortlog_line(row)
        if parsed:
            authors.append(parsed)
    authors.sort(key=lambda item: (-item[0], item[1]))

    return {
        "total_commits": len(all_commits),
        "total_non_merges": len(non_merge_commits),
        "total_merges": len(merge_commits),
        "first_commit": first_commit,
        "last_commit": last_commit,
        "insertions": insertions,
        "deletions": deletions,
        "changed_files_count": len(changed_files),
        "areas": sorted(areas.items(), key=lambda item: (-item[1], item[0])),
        "types": sorted(types.items(), key=lambda item: (-item[1], item[0])),
        "authors": authors,
        "non_merge_commits": non_merge_commits,
        "merge_commits": merge_commits,
    }

