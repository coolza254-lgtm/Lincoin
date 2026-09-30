"""CREDITS.md generated from the sources table of a built content.db."""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path


def credits_markdown(path: Path) -> str:
    db = sqlite3.connect(path)
    version = dict(db.execute("SELECT key, value FROM meta").fetchall()).get("content_version", "")
    lines = [
        "# Credits and licences",
        "",
        f"Lincoin content version {version}. The content database as a whole is distributed "
        "under CC BY-SA 4.0. Individual sources:",
        "",
    ]
    for sid, name, home, lic, lic_url, attribution, ver, files in db.execute(
            "SELECT id, name, homepage, license, license_url, attribution, version, files_json "
            "FROM sources ORDER BY name"):
        lines += [f"## {name}", "", attribution, "", f"- Website: {home}", f"- Licence: {lic} ({lic_url})"]
        if ver:
            lines.append(f"- Version: {ver}")
        for key, rec in json.loads(files).items():
            if rec:
                lines.append(f"- File `{key}`: {rec.get('url')} (sha256 {rec.get('sha256', '')[:16]}…, "
                             f"retrieved {rec.get('retrieved_at', '')})")
        lines.append("")
    n = db.execute("SELECT COUNT(*) FROM examples").fetchone()[0]
    if n:
        lines += ["Example sentence authors are credited next to each sentence in the app.", ""]
    db.close()
    return "\n".join(lines)
