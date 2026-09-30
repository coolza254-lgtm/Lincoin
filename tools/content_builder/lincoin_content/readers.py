"""Readers for the JLPT lists, JmdictFurigana and Tatoeba exports."""
from __future__ import annotations

import bz2
import csv
import gzip
import io
import json
import re
import tarfile
from dataclasses import dataclass
from pathlib import Path

LEVELS = ["n5", "n4", "n3", "n2", "n1"]


# --- JLPT lists (Waller, matched to JMdict by stephenmk) --------------------

@dataclass
class JlptItem:
    seq: int
    kana: str
    kanji: str
    definition: str
    level: int  # 5..1
    index: int  # position in the source list


def read_jlpt(path: Path, level: int) -> list[JlptItem]:
    rows = csv.DictReader(io.StringIO(path.read_text(encoding="utf-8-sig")))
    expected = {"jmdict_seq", "kana", "kanji", "waller_definition"}
    if not expected.issubset(rows.fieldnames or []):
        raise ValueError(f"{path}: unexpected columns {rows.fieldnames}")
    return [
        JlptItem(int(r["jmdict_seq"]), r["kana"].strip(), r["kanji"].strip(),
                 r["waller_definition"].strip(), level, i)
        for i, r in enumerate(rows)
    ]


# --- JmdictFurigana ----------------------------------------------------------

def read_furigana(path: Path, wanted: set[tuple[str, str]]) -> dict[tuple[str, str], list[dict]]:
    """(text, reading) → [{"ruby": .., "rt": ..}, ...] for the wanted pairs."""
    raw = path.read_bytes()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    data = json.loads(raw.decode("utf-8-sig"))
    out = {}
    for item in data:
        key = (item["text"], item["reading"])
        if key in wanted:
            out[key] = [
                {"ruby": p["ruby"], **({"rt": p["rt"]} if p.get("rt") else {})}
                for p in item["furigana"]
            ]
    return out


# --- Tatoeba -------------------------------------------------------------------

NULL = "\\N"


def _open_text(path: Path):
    """Opens .bz2, .tar.bz2 (first member) or plain files as text lines."""
    name = path.name
    if name.endswith(".tar.bz2"):
        tar = tarfile.open(path, "r:bz2")
        member = next(m for m in tar.getmembers() if m.isfile())
        return io.TextIOWrapper(tar.extractfile(member), encoding="utf-8")
    if name.endswith(".bz2"):
        return bz2.open(path, "rt", encoding="utf-8")
    return path.open(encoding="utf-8")


def _rows(path: Path):
    with _open_text(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line:
                yield line.split("\t")


@dataclass
class Sentence:
    id: int
    lang: str
    text: str
    author: str | None


def read_sentences(path: Path, ids: set[int] | None = None) -> dict[int, Sentence]:
    """sentences_detailed format: id, lang, text, username, added, modified."""
    out = {}
    for cols in _rows(path):
        sid = int(cols[0])
        if ids is not None and sid not in ids:
            continue
        author = cols[3] if len(cols) > 3 and cols[3] not in ("", NULL) else None
        out[sid] = Sentence(sid, cols[1], cols[2], author)
    return out


def read_links(path: Path, from_ids: set[int]) -> dict[int, list[int]]:
    out: dict[int, list[int]] = {}
    for cols in _rows(path):
        a, b = int(cols[0]), int(cols[1])
        if a in from_ids:
            out.setdefault(a, []).append(b)
    return out


def read_cc0_ids(path: Path, ids: set[int]) -> set[int]:
    return {int(c[0]) for c in _rows(path) if int(c[0]) in ids}


# Index ("B-line") token: headword(reading)[sense]{surface}~
_TOKEN = re.compile(
    r"^(?P<head>[^(\[{~]+)"
    r"(?:\((?P<reading>[^)]*)\))?"
    r"(?:\[(?P<sense>[0-9]+)\])?"
    r"(?:\{(?P<surface>[^}]*)\})?"
    r"(?P<good>~)?$"
)


@dataclass
class IndexHit:
    sentence_id: int
    headword: str
    reading: str | None
    verified: bool


def parse_index_line(text: str) -> list[tuple[str, str | None, bool]]:
    hits = []
    for tok in text.split():
        m = _TOKEN.match(tok)
        if m:
            hits.append((m.group("head"), m.group("reading"), bool(m.group("good"))))
    return hits


def read_indices(path: Path, forms: dict[str, set[str]]) -> dict[str, list[IndexHit]]:
    """Maps word keys to sentences indexed with them.

    ``forms`` maps a word key to the spellings (kanji and kana) that identify
    it; a hit must use one of them as headword, and when the index gives a
    reading it must be one of the word's spellings too.
    """
    by_spelling: dict[str, set[str]] = {}
    for key, spellings in forms.items():
        for s in spellings:
            by_spelling.setdefault(s, set()).add(key)
    out: dict[str, list[IndexHit]] = {}
    for cols in _rows(path):
        if len(cols) < 3:
            continue
        sid = int(cols[0])
        for head, reading, good in parse_index_line(cols[2]):
            for key in by_spelling.get(head, ()):
                if reading and reading not in forms[key]:
                    continue
                out.setdefault(key, []).append(IndexHit(sid, head, reading, good))
    return out
