"""Draws the reproducible human-audit sample for a level.

    python audit/make_sample.py <worksheet_dir> n5 > audit/n5_sample.json
"""
import json
import random
import sys
from pathlib import Path

SEED = 2026
N_FIRST, N_OTHER, N_EXAMPLES = 100, 50, 100


def main():
    ws, level = Path(sys.argv[1]), sys.argv[2]
    tr = {}
    for kind in ("senses", "examples"):
        for line in (Path(__file__).parent.parent / kind / f"{level}.jsonl").read_text(encoding="utf-8").splitlines():
            r = json.loads(line)
            tr[r["id"]] = r
    senses = [json.loads(l) for l in (ws / f"{level}_senses.jsonl").read_text(encoding="utf-8").splitlines()]
    examples = [json.loads(l) for l in (ws / f"{level}_examples.jsonl").read_text(encoding="utf-8").splitlines()]
    rnd = random.Random(SEED)
    first = [s for s in senses if s["sense"] == 1 and s["id"] in tr]
    other = [s for s in senses if s["sense"] > 1 and s["id"] in tr]
    exs = [e for e in examples if e["id"] in tr]
    picked = rnd.sample(first, N_FIRST) + rnd.sample(other, N_OTHER)
    items = []
    for s in picked:
        t = tr[s["id"]]
        items.append({"id": s["id"], "kind": "sense", "word": s["word"], "reading": s["reading"],
                      "sense": s["sense"], "pos": ", ".join(s["pos"]), "en": s["en"], "th": t["th"],
                      "note": t.get("note") or ""})
    for e in rnd.sample(exs, N_EXAMPLES):
        items.append({"id": e["id"], "kind": "example", "word": e["word"], "ja": e["ja"], "en": e["en"],
                      "th": tr[e["id"]]["th"]})
    rnd.shuffle(items)
    for i, it in enumerate(items):
        it["order"] = i
    json.dump({"level": level, "seed": SEED, "items": items}, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
