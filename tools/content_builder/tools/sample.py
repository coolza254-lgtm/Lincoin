"""Prints a readable sample of a built content.db for review in CI logs."""
import json
import sqlite3
import sys

db = sqlite3.connect(sys.argv[1])
print(dict(db.execute("SELECT key, value FROM meta")))
for lv, n in db.execute("SELECT jlpt_level, COUNT(*) FROM words GROUP BY 1"):
    print(f"N{lv}: {n} words")
rows = db.execute("SELECT id, jlpt_level, order_in_level, tags FROM words ORDER BY jlpt_level DESC, order_in_level")
for i, (wid, lv, order, tags) in enumerate(rows.fetchall()):
    if i >= 40 and i % 50:
        continue
    forms = db.execute("SELECT kind, text, is_primary FROM word_forms WHERE word_id=? ORDER BY kind DESC, ord", (wid,)).fetchall()
    k = next((t for kind, t, p in forms if kind == "kanji" and p), "")
    r = next((t for kind, t, p in forms if kind == "kana" and p), "")
    gloss = db.execute("SELECT gloss_en FROM senses WHERE word_id=? ORDER BY ord LIMIT 2", (wid,)).fetchall()
    ex = db.execute("SELECT e.ja, e.en, e.ja_author FROM word_examples we JOIN examples e ON e.id=we.example_id "
                    "WHERE we.word_id=? ORDER BY rank LIMIT 1", (wid,)).fetchone()
    print(f"#{order:>3} N{lv} {wid:<10} {k or '-':<6} {r:<8} {json.loads(tags)} | "
          f"{' / '.join(g[0] for g in gloss)[:70]}")
    if ex:
        print(f"      ex: {ex[0]} | {ex[1]} ({ex[2]})")
