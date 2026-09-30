"""Validation run after every build. Any error fails the build."""
from __future__ import annotations

import sqlite3
from pathlib import Path


def _count(db, sql) -> int:
    return db.execute(sql).fetchone()[0]


def check(path: Path, report=None) -> list[str]:
    db = sqlite3.connect(path)
    errors = []

    def expect_zero(sql: str, what: str):
        n = _count(db, sql)
        if n:
            errors.append(f"{n} {what}")

    for key in ("schema_version", "content_version", "built_at"):
        if not db.execute("SELECT 1 FROM meta WHERE key=?", (key,)).fetchone():
            errors.append(f"meta.{key} missing")

    # Attribution: every row points at a source with licence and credit text.
    expect_zero("SELECT COUNT(*) FROM sources WHERE trim(license)='' OR trim(license_url)='' OR trim(attribution)=''",
                "sources without licence/attribution")
    for table, col in [("words", "source_id"), ("words", "level_source_id"), ("examples", "source_id"),
                       ("kana", "source_id"), ("grammar_points", "source_id")]:
        expect_zero(f"SELECT COUNT(*) FROM {table} t LEFT JOIN sources s ON s.id=t.{col} WHERE s.id IS NULL",
                    f"{table}.{col} without a registered source")
    expect_zero("SELECT COUNT(*) FROM examples WHERE ja_author IS NULL OR trim(ja_author)=''",
                "examples without a Japanese author")
    expect_zero("SELECT COUNT(*) FROM examples WHERE en IS NOT NULL AND (en_author IS NULL OR trim(en_author)='')",
                "examples without an English author")

    # Structure.
    expect_zero("SELECT COUNT(*) FROM words w WHERE NOT EXISTS (SELECT 1 FROM senses s WHERE s.word_id=w.id)",
                "words without senses")
    expect_zero("SELECT COUNT(*) FROM words w WHERE (SELECT COUNT(*) FROM word_forms f "
                "WHERE f.word_id=w.id AND f.kind='kana' AND f.is_primary=1) <> 1",
                "words without exactly one primary reading")
    expect_zero("SELECT COUNT(*) FROM words w WHERE (SELECT COUNT(*) FROM word_forms f "
                "WHERE f.word_id=w.id AND f.kind='kanji' AND f.is_primary=1) > 1",
                "words with several primary kanji forms")
    expect_zero("SELECT COUNT(*) FROM words w WHERE NOT EXISTS (SELECT 1 FROM word_forms f "
                "WHERE f.word_id=w.id AND f.kind='kana' AND f.accept_as_answer=1)",
                "words with no reading accepted as an answer")
    expect_zero("SELECT COUNT(*) FROM (SELECT jlpt_level, order_in_level FROM words "
                "GROUP BY 1, 2 HAVING COUNT(*) > 1)", "duplicate teaching positions")
    if _count(db, "SELECT COUNT(*) FROM words") == 0:
        errors.append("no words")
    if _count(db, "SELECT COUNT(*) FROM kana") < 200:
        errors.append("kana table incomplete")

    if report is not None and report.override_errors:
        errors.append(f"JLPT overrides that did not resolve to exactly one entry: {report.override_errors}")
    if report is not None and report.missing_in_jmdict:
        errors.append(f"{len(report.missing_in_jmdict)} JLPT list entries not found in JMdict "
                      f"(first: {report.missing_in_jmdict[:5]})")
    db.close()
    return errors
