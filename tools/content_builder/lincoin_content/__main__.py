"""CLI.

    python -m lincoin_content fetch --levels n5
    python -m lincoin_content build --levels n5 --out build/content.db
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .build import build
from .checks import check
from .credits import credits_markdown
from .readers import LEVELS
from .sources import Cache, load_sources

HERE = Path(__file__).resolve().parent.parent


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="lincoin_content")
    p.add_argument("command", choices=["fetch", "build", "worksheet"])
    p.add_argument("--levels", default="n5", help="comma list, e.g. n5,n4")
    p.add_argument("--cache", default=str(HERE / ".cache"))
    p.add_argument("--out", default=str(HERE / "build" / "content.db"))
    p.add_argument("--no-examples", action="store_true")
    p.add_argument("--no-furigana", action="store_true")
    a = p.parse_args(argv)
    levels = [lv.strip().lower() for lv in a.levels.split(",")]
    if any(lv not in LEVELS for lv in levels):
        p.error(f"levels must be among {LEVELS}")
    cache = Cache(Path(a.cache))
    sources = load_sources()

    if a.command == "fetch":
        wanted = [("jmdict", "jmdict")] + [("jlpt_jmdict_match", lv) for lv in levels]
        if not a.no_furigana:
            wanted.append(("jmdict_furigana", "furigana"))
        if not a.no_examples:
            wanted += [("tatoeba", k) for k in sources["tatoeba"].files]
        for sid, key in wanted:
            path = cache.fetch(sources[sid], key)
            rec = cache.record(sid, key)
            print(f"fetched {sid}/{key}: {path.name} {rec['bytes']:,} bytes sha256={rec['sha256'][:12]}")
        return 0

    if a.command == "worksheet":
        from .translations import export_worksheet
        for lv in levels:
            senses, examples = export_worksheet(Path(a.out), int(lv[1]))
            d = HERE / "build" / "worksheet"
            d.mkdir(parents=True, exist_ok=True)
            for name, rows in (("senses", senses), ("examples", examples)):
                (d / f"{lv}_{name}.jsonl").write_text(
                    "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
            print(f"{lv}: {len(senses)} senses, {len(examples)} examples → {d}")
        return 0

    out = Path(a.out)
    report = build(cache, out, levels, with_examples=not a.no_examples, sources=sources)
    errors = check(out, report)
    (out.parent / "report.json").write_text(json.dumps(report.to_json(), ensure_ascii=False, indent=2))
    (out.parent / "CREDITS.md").write_text(credits_markdown(out))
    summary = {k: v for k, v in report.to_json().items() if not isinstance(v, list)}
    summary.update({k: len(v) for k, v in report.to_json().items() if isinstance(v, list) and k != "levels"})
    print(json.dumps(summary, ensure_ascii=False))
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
