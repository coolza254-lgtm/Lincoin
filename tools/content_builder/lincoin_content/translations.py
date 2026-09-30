"""Thai translations kept apart from the source data.

tools/translations/senses/*.jsonl   {"id": "w:<seq>:<n>", "en": <gloss_en at translation time>,
                                     "th": ..., "note": ..., "status": ..., "v": <int>}
tools/translations/examples/*.jsonl {"id": "ex:<id>", "ja": <sentence at translation time>,
                                     "th": ..., "status": ..., "v": <int>}

A translation applies only while its source text is unchanged; if JMdict or
Tatoeba later edits the source, the row is kept but marked ``flagged`` so it
gets reviewed again.
"""
from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "translations"
STATUSES = {"draft", "auto_checked", "flagged", "verified"}
_THAI = re.compile(r"[฀-๿]")


def load(kind: str, root: Path = ROOT) -> dict[str, dict]:
    out: dict[str, dict] = {}
    d = root / kind
    if not d.exists():
        return out
    for f in sorted(d.glob("*.jsonl")):
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            row = json.loads(line)
            if row["id"] in out:
                raise ValueError(f"{f.name}:{n}: duplicate id {row['id']}")
            if row.get("status") not in STATUSES:
                raise ValueError(f"{f.name}:{n}: bad status {row.get('status')}")
            if not row.get("th") or not _THAI.search(row["th"]):
                raise ValueError(f"{f.name}:{n}: 'th' must contain Thai text")
            out[row["id"]] = row
    return out


def apply(db: sqlite3.Connection, root: Path = ROOT) -> dict[str, int]:
    stats = {"senses_translated": 0, "senses_stale": 0, "examples_translated": 0, "examples_stale": 0}
    senses = load("senses", root)
    for sid, en in db.execute("SELECT id, gloss_en FROM senses").fetchall():
        t = senses.get(sid)
        if not t:
            continue
        stale = t["en"] != en
        db.execute("UPDATE senses SET gloss_th=?, note_th=?, th_status=?, th_version=? WHERE id=?",
                   (t["th"], t.get("note"), "flagged" if stale else t["status"], t.get("v", 1), sid))
        stats["senses_stale" if stale else "senses_translated"] += 1
    examples = load("examples", root)
    for eid, ja in db.execute("SELECT id, ja FROM examples").fetchall():
        t = examples.get(eid)
        if t and t["ja"] == ja:
            db.execute("UPDATE examples SET th=? WHERE id=?", (t["th"], eid))
            stats["examples_translated"] += 1
        elif t:
            stats["examples_stale"] += 1
    return stats


def export_worksheet(db_path: Path, level: int) -> tuple[list[dict], list[dict]]:
    """Rows to translate for one JLPT level, with context for the translator."""
    db = sqlite3.connect(db_path)
    senses, examples = [], []
    for wid, order in db.execute("SELECT id, order_in_level FROM words WHERE jlpt_level=? ORDER BY order_in_level",
                                 (level,)).fetchall():
        forms = db.execute("SELECT kind, text FROM word_forms WHERE word_id=? AND is_primary=1", (wid,)).fetchall()
        head = {k: t for k, t in forms}
        for sid, ordn, pos, misc, en in db.execute(
                "SELECT id, ord, pos, misc, gloss_en FROM senses WHERE word_id=? ORDER BY ord", (wid,)):
            senses.append({"id": sid, "word": head.get("kanji") or head.get("kana"), "reading": head.get("kana"),
                           "sense": ordn, "pos": json.loads(pos), "misc": json.loads(misc), "en": en})
        for eid, ja, en in db.execute(
                "SELECT e.id, e.ja, e.en FROM word_examples we JOIN examples e ON e.id=we.example_id "
                "WHERE we.word_id=? ORDER BY we.rank", (wid,)):
            examples.append({"id": eid, "word": head.get("kanji") or head.get("kana"), "ja": ja, "en": en})
    seen = set()
    examples = [e for e in examples if not (e["id"] in seen or seen.add(e["id"]))]
    db.close()
    return senses, examples
