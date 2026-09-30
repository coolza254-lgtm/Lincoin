"""JMdict XML reader.

JMdict encodes part-of-speech and other tags as XML entities whose
replacement text is a long description. We keep the short entity names
instead (e.g. ``v5u``), which are stable codes.
"""
from __future__ import annotations

import gzip
import io
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

_XML_BUILTIN = {"amp", "lt", "gt", "quot", "apos"}
_ENTITY = re.compile(r"&([A-Za-z0-9][A-Za-z0-9_.-]*);")
_CREATED = re.compile(r"<!--\s*JMdict created:\s*([0-9-]+)\s*-->")

# Frequency / commonness markers used by JMdict.
_COMMON = {"news1", "ichi1", "spec1", "spec2", "gai1"}


@dataclass
class KanjiForm:
    text: str
    info: list[str] = field(default_factory=list)
    pri: list[str] = field(default_factory=list)

    @property
    def common(self) -> bool:
        return any(p in _COMMON for p in self.pri)


@dataclass
class ReadingForm:
    text: str
    no_kanji: bool = False
    restr: list[str] = field(default_factory=list)
    info: list[str] = field(default_factory=list)
    pri: list[str] = field(default_factory=list)

    @property
    def common(self) -> bool:
        return any(p in _COMMON for p in self.pri)


@dataclass
class Sense:
    pos: list[str]
    glosses: list[str]
    misc: list[str] = field(default_factory=list)
    field_: list[str] = field(default_factory=list)
    dial: list[str] = field(default_factory=list)
    info: list[str] = field(default_factory=list)
    stagk: list[str] = field(default_factory=list)
    stagr: list[str] = field(default_factory=list)


@dataclass
class Entry:
    seq: int
    kanji: list[KanjiForm]
    readings: list[ReadingForm]
    senses: list[Sense]

    def freq_rank(self) -> int:
        """Lower is more frequent: best nfXX bucket across forms, 99 if none."""
        best = 99
        for f in [*self.kanji, *self.readings]:
            for p in f.pri:
                if p.startswith("nf") and p[2:].isdigit():
                    best = min(best, int(p[2:]))
        return best

    @property
    def common(self) -> bool:
        return any(f.common for f in [*self.kanji, *self.readings])

    @property
    def usually_kana(self) -> bool:
        return bool(self.senses) and all("uk" in s.misc for s in self.senses)


def _read_text(path: Path) -> str:
    raw = path.read_bytes()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return raw.decode("utf-8")


def _strip_entities(xml: str) -> str:
    """Replace custom entity references in the document body by their names."""
    split = xml.find("]>")
    head, body = (xml[: split + 2], xml[split + 2 :]) if split != -1 else ("", xml)
    body = _ENTITY.sub(lambda m: m.group(0) if m.group(1) in _XML_BUILTIN else m.group(1), body)
    # The DOCTYPE is no longer needed once entities are resolved by hand.
    head = re.sub(r"<!DOCTYPE.*\]>", "", head, flags=re.S)
    return head + body


def created_date(path: Path) -> str | None:
    """Build date JMdict writes as a comment after its DTD."""
    opener = gzip.open if _is_gzip(path) else open
    with opener(path, "rt", encoding="utf-8") as f:
        head = f.read(4 << 20)
    m = _CREATED.search(head)
    return m.group(1) if m else None


def _is_gzip(path: Path) -> bool:
    with open(path, "rb") as f:
        return f.read(2) == b"\x1f\x8b"


@dataclass
class Finder:
    """Locates one entry by reading, gloss pattern and optional POS."""
    reading: str
    gloss: str
    pos: str | None = None

    def matches(self, el) -> bool:
        if self.reading not in {(r.text or "") for r in el.findall("r_ele/reb")}:
            return False
        pattern = re.compile(self.gloss, re.I)
        for s in el.findall("sense"):
            if self.pos and self.pos not in _texts(s, "pos"):
                continue
            if any(pattern.search(g.text or "") for g in s.findall("gloss")):
                return True
        return False


def read_entries(path: Path, wanted: set[int] | None = None,
                 finders: list[Finder] | None = None
                 ) -> tuple[dict[int, Entry], dict[str, int], list[list[int]]]:
    """Entries for ``wanted`` sequence numbers, how many entries use each
    spelling across the dictionary, and for each finder the sequence numbers
    of matching entries (those entries are parsed and returned too)."""
    text = _strip_entities(_read_text(path))
    out: dict[int, Entry] = {}
    spelling_counts: dict[str, int] = {}
    finders = finders or []
    hits: list[list[int]] = [[] for _ in finders]
    for _, el in ET.iterparse(io.BytesIO(text.encode("utf-8")), events=("end",)):
        if el.tag != "entry":
            continue
        seq = int(el.findtext("ent_seq"))
        for tag in ("k_ele/keb", "r_ele/reb"):
            for f in el.findall(tag):
                spelling_counts[f.text] = spelling_counts.get(f.text, 0) + 1
        found = False
        for i, fd in enumerate(finders):
            if fd.matches(el):
                hits[i].append(seq)
                found = True
        if found or wanted is None or seq in wanted:
            out[seq] = _parse_entry(seq, el)
        el.clear()
    return out, spelling_counts, hits


def _texts(el, tag) -> list[str]:
    return [(c.text or "").strip() for c in el.findall(tag)]


def _parse_entry(seq: int, el) -> Entry:
    kanji = [
        KanjiForm(k.findtext("keb"), _texts(k, "ke_inf"), _texts(k, "ke_pri"))
        for k in el.findall("k_ele")
    ]
    readings = [
        ReadingForm(
            r.findtext("reb"),
            r.find("re_nokanji") is not None,
            _texts(r, "re_restr"),
            _texts(r, "re_inf"),
            _texts(r, "re_pri"),
        )
        for r in el.findall("r_ele")
    ]
    senses = []
    last_pos: list[str] = []
    for s in el.findall("sense"):
        pos = _texts(s, "pos") or last_pos  # pos carries over to later senses
        last_pos = pos
        glosses = [
            (g.text or "").strip()
            for g in s.findall("gloss")
            if g.get("{http://www.w3.org/XML/1998/namespace}lang", "eng") == "eng"
        ]
        senses.append(
            Sense(
                pos=pos,
                glosses=[g for g in glosses if g],
                misc=_texts(s, "misc"),
                field_=_texts(s, "field"),
                dial=_texts(s, "dial"),
                info=_texts(s, "s_inf"),
                stagk=_texts(s, "stagk"),
                stagr=_texts(s, "stagr"),
            )
        )
    return Entry(seq, kanji, readings, senses)
