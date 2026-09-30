"""Kana table (hiragana and katakana) with Hepburn romaji, in teaching order."""
from __future__ import annotations

# (row id, [(romaji, hiragana)])
_BASIC = [
    ("a", [("a", "あ"), ("i", "い"), ("u", "う"), ("e", "え"), ("o", "お")]),
    ("ka", [("ka", "か"), ("ki", "き"), ("ku", "く"), ("ke", "け"), ("ko", "こ")]),
    ("sa", [("sa", "さ"), ("shi", "し"), ("su", "す"), ("se", "せ"), ("so", "そ")]),
    ("ta", [("ta", "た"), ("chi", "ち"), ("tsu", "つ"), ("te", "て"), ("to", "と")]),
    ("na", [("na", "な"), ("ni", "に"), ("nu", "ぬ"), ("ne", "ね"), ("no", "の")]),
    ("ha", [("ha", "は"), ("hi", "ひ"), ("fu", "ふ"), ("he", "へ"), ("ho", "ほ")]),
    ("ma", [("ma", "ま"), ("mi", "み"), ("mu", "む"), ("me", "め"), ("mo", "も")]),
    ("ya", [("ya", "や"), ("yu", "ゆ"), ("yo", "よ")]),
    ("ra", [("ra", "ら"), ("ri", "り"), ("ru", "る"), ("re", "れ"), ("ro", "ろ")]),
    ("wa", [("wa", "わ"), ("wo", "を")]),
    ("n", [("n", "ん")]),
    ("ga", [("ga", "が"), ("gi", "ぎ"), ("gu", "ぐ"), ("ge", "げ"), ("go", "ご")]),
    ("za", [("za", "ざ"), ("ji", "じ"), ("zu", "ず"), ("ze", "ぜ"), ("zo", "ぞ")]),
    ("da", [("da", "だ"), ("ji", "ぢ"), ("zu", "づ"), ("de", "で"), ("do", "ど")]),
    ("ba", [("ba", "ば"), ("bi", "び"), ("bu", "ぶ"), ("be", "べ"), ("bo", "ぼ")]),
    ("pa", [("pa", "ぱ"), ("pi", "ぴ"), ("pu", "ぷ"), ("pe", "ぺ"), ("po", "ぽ")]),
]

_YOON_BASES = [("k", "き"), ("s", "し"), ("c", "ち"), ("n", "に"), ("h", "ひ"), ("m", "み"),
               ("r", "り"), ("g", "ぎ"), ("j", "じ"), ("b", "び"), ("p", "ぴ")]
_YOON_ROMAJI = {
    "k": "ky", "n": "ny", "h": "hy", "m": "my", "r": "ry", "g": "gy", "b": "by", "p": "py",
    "s": "sh", "c": "ch", "j": "j",
}


def _yoon():
    rows = []
    for base, kana in _YOON_BASES:
        prefix = _YOON_ROMAJI[base]
        items = []
        for vowel, small in (("a", "ゃ"), ("u", "ゅ"), ("o", "ょ")):
            items.append((prefix + vowel, kana + small))
        rows.append((prefix + "a", items))
    return rows


def _to_katakana(s: str) -> str:
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in s)


def kana_rows() -> list[dict]:
    """Rows for the ``kana`` table, hiragana first, then katakana."""
    out = []
    for script in ("hiragana", "katakana"):
        ord_ = 0
        for group, rows in (("basic", _BASIC), ("yoon", _yoon())):
            for row_id, items in rows:
                for romaji, hira in items:
                    ch = hira if script == "hiragana" else _to_katakana(hira)
                    key = romaji if ch not in ("ぢ", "づ", "ヂ", "ヅ") else f"{romaji}_d"
                    out.append({
                        "id": f"k:{script[:4]}.{key}",
                        "script": script,
                        "char": ch,
                        "romaji": romaji,
                        "row": row_id,
                        "grp": group,
                        "ord": ord_,
                    })
                    ord_ += 1
    return out
