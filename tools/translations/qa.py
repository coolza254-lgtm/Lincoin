"""Automatic checks for Thai translations, then conversion to the JSONL
files the content builder reads.

    python qa.py senses <worksheet.jsonl> <work/*.tsv ...> --out senses/n5.jsonl
    python qa.py examples <worksheet.jsonl> <work/*.tsv ...> --out examples/n5.jsonl

TSV rows: id <TAB> thai [<TAB> note]. Rows that pass every check get status
``auto_checked``; rows with a warning get ``flagged`` and are listed in the
report for review.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

THAI = re.compile(r"[฀-๿]")
LATIN_WORD = re.compile(r"[A-Za-z][A-Za-z.\-]*")
DIGITS = re.compile(r"\d[\d,.]*")
# Latin words that legitimately appear in Thai glosses.
ALLOWED_LATIN = {"Homo", "sapiens", "payload", "span", "c", "o", "vs", "TV", "DVD", "CD", "A", "B", "pm", "am"}
JAPANESE = re.compile(r"[぀-ヿ一-鿿]")


def read_tsv(paths: list[Path]) -> dict[str, tuple[str, str | None]]:
    out: dict[str, tuple[str, str | None]] = {}
    for p in paths:
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            cols = line.split("\t")
            if len(cols) < 2:
                raise SystemExit(f"{p.name}:{n}: expected id<TAB>thai[<TAB>note]")
            rid, th = cols[0].strip(), cols[1].strip()
            note = cols[2].strip() if len(cols) > 2 and cols[2].strip() else None
            if rid in out:
                raise SystemExit(f"{p.name}:{n}: duplicate id {rid}")
            out[rid] = (th, note)
    return out


def _balanced(s: str) -> bool:
    depth = 0
    for ch in s:
        depth += ch == "("
        depth -= ch == ")"
        if depth < 0:
            return False
    return depth == 0


def check_row(source: str, th: str, note: str | None, kind: str) -> list[str]:
    w = []
    if not THAI.search(th):
        w.append("no Thai text")
    in_source = set(LATIN_WORD.findall(unicodedata.normalize("NFKC", source)))
    latin = [t for t in LATIN_WORD.findall(th) if t not in ALLOWED_LATIN and t not in in_source]
    if latin:
        w.append(f"Latin words: {latin}")
    if not _balanced(th):
        w.append("unbalanced parentheses")
    if kind == "senses":
        for d in DIGITS.findall(re.sub(r"\^\d+", "", source)):
            if d.rstrip(".,") not in th:
                w.append(f"number {d} missing")
        if len(th) > max(40, 4 * len(source)):
            w.append("much longer than source")
    else:
        # Numbers in the Japanese sentence (full- or half-width) should survive.
        for d in DIGITS.findall(source.translate(str.maketrans("０１２３４５６７８９", "0123456789"))):
            if d.rstrip(".,") not in th:
                w.append(f"number {d} missing")
        if JAPANESE.search(th):
            w.append("Japanese characters left in translation")
    if note is not None and not THAI.search(note):
        w.append("note has no Thai text")
    return w


def translated_elsewhere(out: Path) -> set[str]:
    """Ids already exported to the other jsonl files beside [out]."""
    ids: set[str] = set()
    for p in sorted(out.parent.glob("*.jsonl")):
        if out.exists() and p.resolve() == out.resolve():
            continue
        for line in p.read_text(encoding="utf-8").splitlines():
            if line.strip():
                ids.add(json.loads(line)["id"])
    return ids


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["senses", "examples"])
    ap.add_argument("worksheet", type=Path)
    ap.add_argument("tsv", nargs="+", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--version", type=int, default=1)
    a = ap.parse_args(argv)

    sheet = [json.loads(l) for l in a.worksheet.read_text(encoding="utf-8").splitlines() if l.strip()]
    # An item lives in exactly one jsonl (the builder rejects duplicates). A
    # sentence shared with another level, or a word that moved level, keeps
    # the translation it already has in a sibling file.
    elsewhere = translated_elsewhere(a.out)
    shared = [r["id"] for r in sheet if r["id"] in elsewhere]
    sheet = [r for r in sheet if r["id"] not in elsewhere]
    by_id = {r["id"]: r for r in sheet}
    tr = read_tsv(a.tsv)
    redundant = sorted(set(tr) & set(shared))
    src_key = "en" if a.kind == "senses" else "ja"

    unknown = sorted(set(tr) - set(by_id) - set(redundant))
    missing = [r["id"] for r in sheet if r["id"] not in tr]
    rows, flagged = [], []
    consistency: dict[str, set[str]] = defaultdict(set)
    for r in sheet:
        if r["id"] not in tr:
            continue
        th, note = tr[r["id"]]
        warnings = check_row(r[src_key], th, note, a.kind)
        status = "flagged" if warnings else "auto_checked"
        row = {"id": r["id"], src_key: r[src_key], "th": th}
        if a.kind == "senses":
            row["note"] = note
            consistency[r["en"]].add(th)
        row.update({"status": status, "v": a.version})
        rows.append(row)
        if warnings:
            flagged.append({"id": r["id"], "source": r[src_key], "th": th, "warnings": warnings})

    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text("".join(json.dumps(x, ensure_ascii=False) + "\n" for x in rows), encoding="utf-8")
    inconsistent = {en: sorted(ths) for en, ths in consistency.items() if len(ths) > 1}
    report = {
        "translated": len(rows),
        "auto_checked": sum(r["status"] == "auto_checked" for r in rows),
        "flagged": flagged,
        "missing": missing,
        "unknown_ids": unknown,
        "translated_elsewhere": len(shared),
        "redundant_ids": redundant,
        "same_source_different_thai": inconsistent,
    }
    rep_path = a.out.with_suffix(".qa.json")
    rep_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{a.kind}: {len(rows)} translated, {report['auto_checked']} auto_checked, "
          f"{len(flagged)} flagged, {len(missing)} missing, {len(unknown)} unknown ids, "
          f"{len(shared)} translated in another file ({len(redundant)} redundant here), "
          f"{len(inconsistent)} sources with different Thai → {rep_path.name}")
    # Rows for items not in the current worksheet are kept: they apply again
    # if the item returns (e.g. example selection changes).
    return 0


if __name__ == "__main__":
    sys.exit(main())
