"""Grammar points (original Lincoin text in ../grammar/n<level>.json) and
the Tatoeba sentences used as their examples and cloze questions.

Each point lists regex patterns; the pattern's group is the part blanked in
a cloze. A sentence qualifies when it is short, has a named author and an
English translation, passes the content filter, and contains the blanked
text exactly once (so the answer is not visible elsewhere in the sentence).
Easier sentences (fewer kanji outside the level's vocabulary) come first.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

GRAMMAR_DIR = Path(__file__).resolve().parents[1] / "grammar"
MAX_EXAMPLES = 6
MAX_LEN = 22
_KANJI = re.compile(r"[一-龯々]")


@dataclass
class Point:
    id: str
    level: int
    ord: int
    title_ja: str
    title_th: str
    meaning_th: str
    formation_th: str
    notes_th: str | None
    similar: list[str]
    patterns: list[tuple[re.Pattern, int]]
    wrong: list[str]


def load_points(level: int, root: Path = GRAMMAR_DIR) -> list[Point]:
    path = root / f"n{level}.json"
    if not path.exists():
        return []
    out = []
    for p in json.loads(path.read_text(encoding="utf-8")):
        out.append(Point(
            p["id"], p["level"], p["ord"], p["title_ja"], p["title_th"], p["meaning_th"],
            p["formation_th"], p.get("notes_th"), p.get("similar", []),
            [(re.compile(q["regex"]), q.get("group", 1)) for q in p["patterns"]],
            p["wrong"]))
    ids = {p.id for p in out}
    for p in out:
        missing = [s for s in p.similar if s not in ids]
        if missing:
            raise ValueError(f"{p.id}: unknown similar ids {missing}")
        if len(p.wrong) < 2:
            raise ValueError(f"{p.id}: needs at least 2 wrong options")
    return out


@dataclass
class Match:
    sentence_id: int
    start: int
    end: int
    answer: str
    wrong: list[str]


def unknown_kanji(text: str, known: set[str]) -> int:
    return sum(1 for ch in _KANJI.findall(text) if ch not in known)


def find_examples(points: list[Point], sentences: dict[int, str], known_kanji: set[str],
                  exclude: dict[str, set[int]] | None = None) -> dict[str, list[Match]]:
    """[sentences]: id → Japanese text, already filtered (author, English,
    content filter). Returns up to MAX_EXAMPLES matches per point."""
    exclude = exclude or {}
    short = {sid: t for sid, t in sentences.items() if len(t) <= MAX_LEN}
    out: dict[str, list[Match]] = {}
    for p in points:
        cands: list[tuple[tuple, Match]] = []
        for sid, text in short.items():
            if sid in exclude.get(p.id, set()):
                continue
            for rx, group in p.patterns:
                m = rx.search(text)
                if not m:
                    continue
                answer = m.group(group)
                if not answer or text.count(answer) != 1:
                    continue
                wrong = [w for w in p.wrong if w != answer][:3]
                match = Match(sid, m.start(group), m.end(group), answer, wrong)
                cands.append(((unknown_kanji(text, known_kanji), len(text), sid), match))
                break
        cands.sort(key=lambda c: c[0])
        out[p.id] = [m for _, m in cands[:MAX_EXAMPLES]]
    return out


def load_exclusions(level: int, root: Path = GRAMMAR_DIR) -> dict[str, set[int]]:
    """Sentences reviewed as bad examples for a point (grammar/n5_exclude.json:
    {"g:n5.001": [123, 456]})."""
    path = root / f"n{level}_exclude.json"
    if not path.exists():
        return {}
    return {k: set(v) for k, v in json.loads(path.read_text(encoding="utf-8")).items()}
