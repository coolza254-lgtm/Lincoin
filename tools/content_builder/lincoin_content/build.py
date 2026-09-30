"""Builds content.db from cached source files."""
from __future__ import annotations

import datetime as _dt
import json
import re
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path

from . import grammar, jmdict, readers
from . import translations
from .kana import kana_rows
from .sources import Cache, Source, load_sources

SCHEMA = Path(__file__).with_name("schema.sql")
SCHEMA_VERSION = 1

# Forms JMdict marks as irregular, outdated, rare or search-only are kept for
# reference but never shown as the headword.
_IRREGULAR = {"iK", "ik", "io", "oK", "ok", "rK", "rk", "sK", "sk", "ateji", "gikun"}
MAX_EXAMPLES = 2
PREFERRED_EXAMPLE_LEN = 25


@dataclass
class BuildReport:
    levels: list[str]
    words: int = 0
    senses: int = 0
    examples: int = 0
    words_with_examples: int = 0
    words_with_furigana: int = 0
    kanji_words: int = 0
    kana: int = 0
    missing_in_jmdict: list[dict] = field(default_factory=list)
    duplicate_list_entries: list[int] = field(default_factory=list)
    primary_form_fallbacks: list[dict] = field(default_factory=list)
    skipped_sentences_without_author: int = 0
    skipped_unsuitable_sentences: int = 0
    words_without_examples: list[int] = field(default_factory=list)
    translations: dict = field(default_factory=dict)
    overrides_applied: list[dict] = field(default_factory=list)
    override_errors: list[dict] = field(default_factory=list)
    grammar_points: int = 0
    grammar_examples: int = 0
    grammar_points_few_examples: list[str] = field(default_factory=list)

    def to_json(self) -> dict:
        return self.__dict__


def _j(v) -> str:
    return json.dumps(v, ensure_ascii=False)


def _nf(pri: list[str]) -> int:
    return min((int(p[2:]) for p in pri if p.startswith("nf") and p[2:].isdigit()), default=99)


def _pick_primary(entry: jmdict.Entry, item: readers.JlptItem, report: BuildReport):
    kanji = [k for k in entry.kanji if not set(k.info) & _IRREGULAR]
    primary_k = next((k.text for k in entry.kanji if k.text == item.kanji), None)
    if item.kanji and primary_k is None:
        primary_k = kanji[0].text if kanji else None
        report.primary_form_fallbacks.append(
            {"seq": entry.seq, "list_kanji": item.kanji, "used": primary_k})
    if not item.kanji:
        primary_k = None

    def fits(r: jmdict.ReadingForm) -> bool:
        return not primary_k or ((not r.no_kanji) and (not r.restr or primary_k in r.restr))

    primary_r = next((r.text for r in entry.readings if r.text == item.kana and fits(r)), None)
    if primary_r is None:
        primary_r = next((r.text for r in entry.readings if fits(r) and not set(r.info) & _IRREGULAR),
                         entry.readings[0].text)
        report.primary_form_fallbacks.append(
            {"seq": entry.seq, "list_kana": item.kana, "used": primary_r})
    return primary_k, primary_r


def load_overrides(path: Path | None) -> list[dict]:
    if path is None or not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))["overrides"]


OVERRIDES = Path(__file__).resolve().parent.parent / "jlpt_overrides.json"
EXAMPLE_FILTER = Path(__file__).resolve().parent.parent / "example_filter.json"


class ExampleFilter:
    """Rejects sentences unsuitable for an all-ages learning app."""

    def __init__(self, path: Path | None = EXAMPLE_FILTER):
        data = json.loads(path.read_text(encoding="utf-8")) if path and path.exists() else {}
        self.en = [re.compile(p, re.I) for p in data.get("english", [])]
        self.ja = list(data.get("japanese", []))

    def blocked(self, ja: str, en: str | None) -> bool:
        return any(w in ja for w in self.ja) or bool(en and any(p.search(en) for p in self.en))


def build(cache: Cache, out: Path, levels: list[str], with_examples: bool = True,
          sources: dict[str, Source] | None = None,
          translations_root: Path | None = translations.ROOT,
          overrides_path: Path | None = OVERRIDES,
          example_filter: ExampleFilter | None = None,
          grammar_root: Path = grammar.GRAMMAR_DIR) -> BuildReport:
    sources = sources or load_sources()
    report = BuildReport(levels=levels)

    # 1. JLPT items; a word listed at several levels keeps the easiest one.
    items: dict[int, readers.JlptItem] = {}
    list_readings: dict[int, list[str]] = {}
    for lv in levels:
        for it in readers.read_jlpt(cache.path("jlpt_jmdict_match", lv), int(lv[1])):
            if it.kana not in list_readings.setdefault(it.seq, []):
                list_readings[it.seq].append(it.kana)
            if it.seq in items:
                report.duplicate_list_entries.append(it.seq)
                if it.level <= items[it.seq].level:
                    continue
            items[it.seq] = it

    # 2. Dictionary entries, applying reviewed corrections to the list matching.
    jm_path = cache.path("jmdict", "jmdict")
    overrides = [o for o in load_overrides(overrides_path) if o["seq"] in items]
    finders = [jmdict.Finder(o["reading"], o["gloss"], o.get("pos")) for o in overrides]
    entries, spelling_counts, hits = jmdict.read_entries(jm_path, set(items), finders)
    for o, found in zip(overrides, hits):
        if len(found) != 1:
            report.override_errors.append({"seq": o["seq"], "reading": o["reading"], "matches": found})
            continue
        old = items.pop(o["seq"])
        new_seq = found[0]
        items[new_seq] = readers.JlptItem(new_seq, old.kana, old.kanji if old.kanji else "",
                                          old.definition, old.level, old.index)
        list_readings[new_seq] = list_readings.pop(o["seq"], [old.kana])
        report.overrides_applied.append({"from": o["seq"], "to": new_seq, "reason": o["reason"]})
    for seq, it in items.items():
        if seq not in entries:
            report.missing_in_jmdict.append({"seq": seq, "kanji": it.kanji, "kana": it.kana})

    # 3. Order within each level: frequent and common words first.
    by_level: dict[int, list[int]] = {}
    for seq in items:
        if seq in entries:
            by_level.setdefault(items[seq].level, []).append(seq)
    order: dict[int, int] = {}
    for lv, seqs in by_level.items():
        seqs.sort(key=lambda s: (entries[s].freq_rank(), not entries[s].common, items[s].index))
        order.update({s: i for i, s in enumerate(seqs)})

    # A word listed with several readings (e.g. 四 し/よん) teaches the most
    # frequent one first; every listed reading stays accepted.
    for seq in order:
        taught = list_readings.get(seq, [])
        if len(taught) > 1:
            rank = {r.text: (not r.common, _nf(r.pri), i) for i, r in enumerate(entries[seq].readings)}
            best = min(taught, key=lambda k: rank.get(k, (True, 99, 99)))
            items[seq] = readers.JlptItem(seq, best, items[seq].kanji, items[seq].definition,
                                          items[seq].level, items[seq].index)
    primaries = {seq: _pick_primary(entries[seq], items[seq], report) for seq in order}

    # 4. Furigana for kanji forms.
    furigana = {}
    if cache.has("jmdict_furigana", "furigana"):
        wanted_pairs = set()
        for seq in order:
            e = entries[seq]
            for k in e.kanji:
                for r in e.readings:
                    if not r.no_kanji and (not r.restr or k.text in r.restr):
                        wanted_pairs.add((k.text, r.text))
        furigana = readers.read_furigana(cache.path("jmdict_furigana", "furigana"), wanted_pairs)

    # 5. Example sentences.
    word_examples: dict[int, list[tuple[readers.Sentence, readers.Sentence | None, bool]]] = {}
    cc0: set[int] = set()
    if with_examples:
        word_examples, cc0 = _examples(cache, entries, order, primaries, spelling_counts, report,
                                       example_filter or ExampleFilter())

    # 6. Write the database.
    if out.exists():
        out.unlink()
    out.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(out)
    db.executescript(SCHEMA.read_text())
    now = _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds")
    jm_date = jmdict.created_date(jm_path)
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        # Date plus UTC time, so several builds on one day still increase.
        "content_version": f"{_dt.datetime.now(_dt.timezone.utc):%Y.%m.%d.%H%M}",
        "built_at": now,
        "levels": ",".join(levels),
        "jmdict_created": jm_date or "",
    }
    db.executemany("INSERT INTO meta VALUES (?, ?)", meta.items())

    used_sources = {"jmdict", "jlpt_tanos", "jlpt_jmdict_match", "lincoin"}
    if furigana:
        used_sources.add("jmdict_furigana")
    if word_examples:
        used_sources.add("tatoeba")
    for sid in sorted(used_sources):
        s = sources[sid]
        files = {k: cache.record(sid, k) for k in s.files if cache.has(sid, k)}
        version = s.version or (jm_date if sid == "jmdict" else None)
        db.execute("INSERT INTO sources VALUES (?,?,?,?,?,?,?,?)",
                   (s.id, s.name, s.homepage, s.license, s.license_url, s.attribution, version, _j(files)))

    for seq in sorted(order, key=lambda s: (-items[s].level, order[s])):
        e, it = entries[seq], items[seq]
        wid = f"w:{seq}"
        primary_k, primary_r = primaries[seq]
        tags = (["uk"] if e.usually_kana else []) + (["common"] if e.common else [])
        db.execute("INSERT INTO words VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                   (wid, it.level, order[seq], _j(e.senses[0].pos if e.senses else []), _j(tags),
                    int(e.common), e.freq_rank(), "jmdict", "jlpt_jmdict_match", it.definition,
                    _j(list_readings.get(seq, [it.kana]))))
        report.words += 1
        if primary_k:
            report.kanji_words += 1
        for i, k in enumerate(e.kanji):
            fg = furigana.get((k.text, primary_r)) if primary_r else None
            if k.text == primary_k and fg:
                report.words_with_furigana += 1
            db.execute("INSERT INTO word_forms VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (wid, "kanji", i, k.text, _j(fg) if fg else None, None, _j(k.info),
                        int(k.text == primary_k), int(k.common), 0))
        for i, r in enumerate(e.readings):
            db.execute("INSERT INTO word_forms VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (wid, "kana", i, r.text, None, _j(r.restr) if r.restr else None, _j(r.info),
                        int(r.text == primary_r), int(r.common), int("sk" not in r.info)))
        for i, s in enumerate(e.senses):
            if not s.glosses:
                continue
            db.execute("INSERT INTO senses VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                       (f"{wid}:{i + 1}", wid, i + 1, _j(s.pos), _j(s.misc), _j(s.field_), _j(s.info),
                        _j(s.stagk + s.stagr), "; ".join(s.glosses), None, None, "missing", 0))
            report.senses += 1

    report.words_without_examples = sorted(s for s in order if not word_examples.get(s)) if with_examples else []
    seen_examples = set()
    for seq, rows in word_examples.items():
        if seq not in order:
            continue
        if rows:
            report.words_with_examples += 1
        for rank, (ja, en, verified) in enumerate(rows):
            eid = f"ex:{ja.id}"
            if eid not in seen_examples:
                seen_examples.add(eid)
                db.execute("INSERT INTO examples VALUES (?,?,?,?,?,?,?,?,?,?)",
                           (eid, ja.text, None, en.text if en else None, None, ja.author,
                            en.author if en else None,
                            "CC0 1.0" if ja.id in cc0 else "CC BY 2.0 FR",
                            ("CC0 1.0" if en.id in cc0 else "CC BY 2.0 FR") if en else None,
                            "tatoeba"))
                report.examples += 1
            db.execute("INSERT INTO word_examples VALUES (?,?,?,?)", (f"w:{seq}", eid, rank, int(verified)))

    # 7. Grammar points with example sentences.
    points = [p for lv in levels for p in grammar.load_points(int(lv[1]), grammar_root)]
    if points:
        known = {ch for (t,) in db.execute("SELECT text FROM word_forms WHERE kind='kanji'")
                 for ch in t}
        known |= set("一二三四五六七八九十百千万円時分日月年人")
        matches, sents = ({}, {})
        if with_examples:
            exclude: dict[str, set[int]] = {}
            for lv in levels:
                exclude.update(grammar.load_exclusions(int(lv[1]), grammar_root))
            matches, sents = _grammar_examples(cache, points, known, exclude,
                                               example_filter or ExampleFilter())
            if sents:
                used = {s for (s,) in db.execute("SELECT id FROM sources")}
                if "tatoeba" not in used:
                    t = sources["tatoeba"]
                    files = {k: cache.record("tatoeba", k) for k in t.files if cache.has("tatoeba", k)}
                    db.execute("INSERT INTO sources VALUES (?,?,?,?,?,?,?,?)",
                               (t.id, t.name, t.homepage, t.license, t.license_url, t.attribution,
                                t.version, _j(files)))
        for p in points:
            db.execute("INSERT INTO grammar_points VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                       (p.id, p.level, p.ord, p.title_ja, p.title_th, p.meaning_th, p.formation_th,
                        p.notes_th, _j(p.similar), "auto_checked", "lincoin"))
            report.grammar_points += 1
            rows = matches.get(p.id, [])
            if with_examples and len(rows) < 3:
                report.grammar_points_few_examples.append(p.id)
            for rank, m in enumerate(rows):
                ja, en, cc0_ja, cc0_en = sents[m.sentence_id]
                eid = f"ex:{m.sentence_id}"
                if eid not in seen_examples:
                    seen_examples.add(eid)
                    db.execute("INSERT INTO examples VALUES (?,?,?,?,?,?,?,?,?,?)",
                               (eid, ja.text, None, en.text, None, ja.author, en.author,
                                "CC0 1.0" if cc0_ja else "CC BY 2.0 FR",
                                "CC0 1.0" if cc0_en else "CC BY 2.0 FR", "tatoeba"))
                    report.examples += 1
                db.execute("INSERT INTO grammar_examples VALUES (?,?,?,?)",
                           (p.id, eid, rank, _j({"start": m.start, "end": m.end,
                                                  "answer": m.answer, "wrong": m.wrong})))
                report.grammar_examples += 1

    report.translations = translations.apply(db, translations_root) if translations_root else {}

    for k in kana_rows():
        db.execute("INSERT INTO kana VALUES (?,?,?,?,?,?,?,?)",
                   (k["id"], k["script"], k["char"], k["romaji"], k["row"], k["grp"], k["ord"], "lincoin"))
        report.kana += 1

    db.commit()
    db.execute("VACUUM")
    db.close()
    return report


def _examples(cache, entries, order, primaries, spelling_counts, report, flt: ExampleFilter):
    """Up to MAX_EXAMPLES Tatoeba sentences per word, with English translations
    and a named author. Hits without an explicit reading are used only when
    the spelling belongs to a single JMdict entry, to avoid homograph mix-ups."""
    forms: dict[str, set[str]] = {}
    for seq in order:
        e = entries[seq]
        spellings = {k.text for k in e.kanji if not set(k.info) & _IRREGULAR}
        spellings |= {r.text for r in e.readings if not set(r.info) & _IRREGULAR}
        forms[str(seq)] = spellings
    hits = readers.read_indices(cache.path("tatoeba", "jpn_indices"), forms)
    accepted: dict[int, list[readers.IndexHit]] = {}
    for key, hs in hits.items():
        seq = int(key)
        ok = [h for h in hs if h.reading or spelling_counts.get(h.headword, 0) == 1]
        if ok:
            accepted[seq] = ok

    sentence_ids = {h.sentence_id for hs in accepted.values() for h in hs}
    jpn = readers.read_sentences(cache.path("tatoeba", "jpn_sentences"), sentence_ids)
    links = readers.read_links(cache.path("tatoeba", "jpn_eng_links"), set(jpn))
    eng_ids = {t for ts in links.values() for t in ts}
    eng = readers.read_sentences(cache.path("tatoeba", "eng_sentences"), eng_ids)
    cc0 = readers.read_cc0_ids(cache.path("tatoeba", "cc0"), set(jpn) | set(eng))

    out = {}
    no_author: set[int] = set()
    blocked: set[int] = set()
    for seq, hs in accepted.items():
        verified = {h.sentence_id for h in hs if h.verified}
        cands = []
        for sid in {h.sentence_id for h in hs}:
            ja = jpn.get(sid)
            if ja is None:
                continue
            if not ja.author:
                no_author.add(sid)
                continue
            en = next((eng[t] for t in sorted(links.get(sid, [])) if t in eng and eng[t].author), None)
            if en is None:
                continue
            if flt.blocked(ja.text, en.text):
                blocked.add(sid)
                continue
            cands.append((ja, en, sid in verified))
        # Short sentences first (beginner-friendly), then ones Tatoeba marks as
        # good examples of the word, then shorter.
        cands.sort(key=lambda c: (len(c[0].text) > PREFERRED_EXAMPLE_LEN, not c[2], len(c[0].text), c[0].id))
        out[seq] = cands[:MAX_EXAMPLES]
    report.skipped_sentences_without_author = len(no_author)
    report.skipped_unsuitable_sentences = len(blocked)
    return out, cc0


def _grammar_examples(cache, points, known_kanji, exclude, flt: ExampleFilter):
    """Scans every Japanese Tatoeba sentence that has an authored English
    translation for the grammar patterns."""
    jpn = {sid: s for sid, s in readers.read_sentences(cache.path("tatoeba", "jpn_sentences")).items()
           if s.author and len(s.text) <= grammar.MAX_LEN}
    links = readers.read_links(cache.path("tatoeba", "jpn_eng_links"), set(jpn))
    eng_ids = {t for ts in links.values() for t in ts}
    eng = readers.read_sentences(cache.path("tatoeba", "eng_sentences"), eng_ids)
    usable: dict[int, tuple] = {}
    for sid, ja in jpn.items():
        en = next((eng[t] for t in sorted(links.get(sid, [])) if t in eng and eng[t].author), None)
        if en is None or flt.blocked(ja.text, en.text):
            continue
        usable[sid] = (ja, en)
    matches = grammar.find_examples(points, {sid: ja.text for sid, (ja, _) in usable.items()},
                                    known_kanji, exclude)
    wanted = {m.sentence_id for ms in matches.values() for m in ms}
    ids = wanted | {usable[s][1].id for s in wanted}
    cc0 = readers.read_cc0_ids(cache.path("tatoeba", "cc0"), ids)
    sents = {s: (usable[s][0], usable[s][1], s in cc0, usable[s][1].id in cc0) for s in wanted}
    return matches, sents
