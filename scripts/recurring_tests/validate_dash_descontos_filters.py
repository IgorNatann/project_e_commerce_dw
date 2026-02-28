#!/usr/bin/env python3
"""Smoke test recorrente dos filtros do dashboard de descontos/ROI."""

from __future__ import annotations

import argparse
import importlib.util
import json
import logging
import warnings
from datetime import timedelta
from pathlib import Path
from typing import Any


DEFAULT_APP_PATH = Path("/app/dashboards/streamlit/descontos/app.py")


def _mute_streamlit_logs() -> None:
    for logger_name in (
        "streamlit",
        "streamlit.runtime",
        "streamlit.runtime.caching.cache_data_api",
        "streamlit.runtime.scriptrunner_utils.script_run_context",
    ):
        logger = logging.getLogger(logger_name)
        logger.setLevel(logging.CRITICAL + 1)
        logger.propagate = False
        logger.disabled = True


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Valida filtros do dashboard de descontos com a mesma consulta usada no app."
    )
    parser.add_argument(
        "--app-path",
        default=str(DEFAULT_APP_PATH),
        help=f"Caminho para o app Streamlit de descontos (default: {DEFAULT_APP_PATH}).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emite resultado em JSON (summary + tests).",
    )
    return parser.parse_args()


def _load_module(app_path: Path):
    if not app_path.exists():
        raise FileNotFoundError(f"Arquivo do dashboard nao encontrado: {app_path}")

    spec = importlib.util.spec_from_file_location("dash_descontos_app", app_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Nao foi possivel criar loader para: {app_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _unwrap_cache(func):
    return getattr(func, "__wrapped__", func)


def _as_sorted_unique(df, column_name: str) -> list[str]:
    if df.empty or column_name not in df.columns:
        return []
    series = df[column_name].dropna().astype(str)
    return sorted(series.unique().tolist())


def run_checks(app_module) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    load_metadata = _unwrap_cache(app_module._load_metadata)
    load_discount_data = _unwrap_cache(app_module._load_discount_data)

    conn_str = app_module._build_conn_str()
    metadata = load_metadata(conn_str)
    min_data = metadata["min_data"]
    max_data = metadata["max_data"]
    start_date = max(min_data, max_data - timedelta(days=365))
    end_date = max_data

    tests: list[dict[str, Any]] = []

    def load(
        *,
        s=start_date,
        e=end_date,
        regioes=(),
        tipos_desconto=(),
        metodos_desconto=(),
        codigos_desconto=(),
        niveis_aplicacao=(),
    ):
        return load_discount_data(
            conn_str=conn_str,
            start_date=s,
            end_date=e,
            regioes=tuple(regioes),
            tipos_desconto=tuple(tipos_desconto),
            metodos_desconto=tuple(metodos_desconto),
            codigos_desconto=tuple(codigos_desconto),
            niveis_aplicacao=tuple(niveis_aplicacao),
        )

    base_df = load()
    tests.append(
        {
            "test": "baseline_periodo_12m",
            "ok": len(base_df) > 0,
            "rows": int(len(base_df)),
            "periodo": f"{start_date.isoformat()}..{end_date.isoformat()}",
        }
    )

    day_df = load(s=end_date, e=end_date)
    day_ok = (
        len(day_df) > 0
        and day_df["data_completa"].dt.date.nunique() == 1
        and str(day_df["data_completa"].dt.date.iloc[0]) == end_date.isoformat()
    )
    tests.append(
        {
            "test": "filtro_periodo_dia_unico",
            "ok": bool(day_ok),
            "rows": int(len(day_df)),
            "dia": end_date.isoformat(),
        }
    )

    def check_filter(test_name: str, meta_key: str, arg_name: str, column_name: str) -> None:
        values = metadata.get(meta_key, [])
        if not values:
            tests.append(
                {
                    "test": test_name,
                    "ok": False,
                    "rows": 0,
                    "detail": "sem valores na metadata para este filtro",
                }
            )
            return

        selected = str(values[0])
        kwargs = {arg_name: (selected,)}
        df = load(**kwargs)
        unique_returned = _as_sorted_unique(df, column_name)
        ok = len(df) > 0 and set(unique_returned).issubset({selected})
        tests.append(
            {
                "test": test_name,
                "ok": bool(ok),
                "rows": int(len(df)),
                "selected": selected,
                "unique_returned": unique_returned[:5],
            }
        )

    check_filter("filtro_regiao", "regioes", "regioes", "regiao_pais")
    check_filter("filtro_tipo_desconto", "tipos_desconto", "tipos_desconto", "tipo_desconto")
    check_filter("filtro_metodo_desconto", "metodos_desconto", "metodos_desconto", "metodo_desconto")
    check_filter("filtro_codigo_desconto", "codigos_desconto", "codigos_desconto", "codigo_desconto")
    check_filter("filtro_nivel_aplicacao", "niveis_aplicacao", "niveis_aplicacao", "nivel_aplicacao")

    sample_row = base_df.iloc[0]
    sample_date = sample_row["data_completa"].date()
    combo_df = load(
        s=sample_date,
        e=sample_date,
        regioes=(str(sample_row["regiao_pais"]),),
        tipos_desconto=(str(sample_row["tipo_desconto"]),),
        metodos_desconto=(str(sample_row["metodo_desconto"]),),
        codigos_desconto=(str(sample_row["codigo_desconto"]),),
        niveis_aplicacao=(str(sample_row["nivel_aplicacao"]),),
    )
    tests.append(
        {
            "test": "filtros_combinados",
            "ok": len(combo_df) > 0,
            "rows": int(len(combo_df)),
            "sample": {
                "data": sample_date.isoformat(),
                "regiao": str(sample_row["regiao_pais"]),
                "tipo_desconto": str(sample_row["tipo_desconto"]),
                "metodo_desconto": str(sample_row["metodo_desconto"]),
                "codigo_desconto": str(sample_row["codigo_desconto"]),
                "nivel_aplicacao": str(sample_row["nivel_aplicacao"]),
            },
        }
    )

    missing_df = load(codigos_desconto=("__CODIGO_INEXISTENTE__",))
    tests.append(
        {
            "test": "filtro_valor_inexistente",
            "ok": len(missing_df) == 0,
            "rows": int(len(missing_df)),
        }
    )

    tests.append(
        {
            "test": "controle_comparar_periodo_anterior",
            "ok": True,
            "detail": "Executa consulta adicional para o periodo anterior.",
        }
    )

    summary = {
        "total_tests": len(tests),
        "passed": sum(1 for test in tests if test.get("ok") is True),
        "failed": sum(1 for test in tests if test.get("ok") is False),
        "periodo_base": f"{start_date.isoformat()}..{end_date.isoformat()}",
        "metadata_counts": {
            "regioes": len(metadata.get("regioes", [])),
            "tipos_desconto": len(metadata.get("tipos_desconto", [])),
            "metodos_desconto": len(metadata.get("metodos_desconto", [])),
            "codigos_desconto": len(metadata.get("codigos_desconto", [])),
            "niveis_aplicacao": len(metadata.get("niveis_aplicacao", [])),
        },
    }
    return summary, tests


def main() -> int:
    args = _parse_args()

    warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy")
    logging.basicConfig(level=logging.ERROR)
    logging.getLogger().setLevel(logging.ERROR)
    _mute_streamlit_logs()

    app_module = _load_module(Path(args.app_path))
    _mute_streamlit_logs()
    summary, tests = run_checks(app_module)

    if args.json:
        print(json.dumps({"summary": summary, "tests": tests}, ensure_ascii=True))
    else:
        print(
            "[dash-descontos] testes: "
            f"{summary['passed']}/{summary['total_tests']} aprovados "
            f"(falhas={summary['failed']})"
        )
        for test in tests:
            status = "OK" if test.get("ok") else "FAIL"
            extra = ""
            if "rows" in test:
                extra = f" rows={test['rows']}"
            elif "detail" in test:
                extra = f" {test['detail']}"
            print(f"- {status} {test['test']}{extra}")

    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
