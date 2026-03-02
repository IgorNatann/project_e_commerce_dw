"""Configuracoes de apresentacao dos testes para melhor leitura no terminal."""

from __future__ import annotations

from collections import defaultdict

import pytest


def _first_doc_line(item: pytest.Item) -> str:
    """Retorna a primeira linha util da docstring do teste."""
    test_obj = getattr(item, "obj", None)
    if test_obj is None:
        return "Sem descricao."

    doc = getattr(test_obj, "__doc__", "") or ""
    lines = [line.strip() for line in doc.strip().splitlines() if line.strip()]
    return lines[0] if lines else "Sem descricao."


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item, call: pytest.CallInfo[object]):
    """Anexa descricao do cenario no report para exibir no resumo final."""
    outcome = yield
    report = outcome.get_result()
    if report.when != "call":
        return

    report.user_properties.append(("scenario", _first_doc_line(item)))


def pytest_terminal_summary(
    terminalreporter: pytest.TerminalReporter,
    exitstatus: int,
    config: pytest.Config,
) -> None:
    """Imprime resumo visual com status e cenario de cada teste executado."""
    del exitstatus, config

    by_status: dict[str, list[pytest.TestReport]] = defaultdict(list)
    ordered_statuses = ("passed", "failed", "skipped", "xfailed", "xpassed", "error")

    for status in ordered_statuses:
        for report in terminalreporter.stats.get(status, []):
            if getattr(report, "when", None) == "call":
                by_status[status].append(report)

    if not any(by_status.values()):
        return

    terminalreporter.write_sep("=", "Resumo visual dos testes")

    visual = {
        "passed": ("PASS", {"green": True}),
        "failed": ("FAIL", {"red": True}),
        "error": ("ERROR", {"red": True, "bold": True}),
        "skipped": ("SKIP", {"yellow": True}),
        "xfailed": ("XFAIL", {"yellow": True}),
        "xpassed": ("XPASS", {"yellow": True}),
    }

    for status in ordered_statuses:
        reports = by_status[status]
        if not reports:
            continue

        label, style = visual[status]
        terminalreporter.write_line(f"{label}: {len(reports)}", **style)
        for report in reports:
            scenario = dict(getattr(report, "user_properties", [])).get("scenario", "Sem descricao.")
            terminalreporter.write_line(f"  - {report.nodeid}")
            terminalreporter.write_line(f"    cenario: {scenario}")

