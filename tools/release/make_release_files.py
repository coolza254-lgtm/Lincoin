"""Builds the files attached to a GitHub Release (docs/10-updates.md):

  content-<version>.lincoin-content   zip of content.db + manifest.json
  latest.json                         what the app's "ตรวจหาอัปเดต" reads

    python3 tools/release/make_release_files.py \
        --content app/assets/content/content.db --out dist \
        --repo coolza254-lgtm/Lincoin --tag v0.1.0 \
        [--apk dist/lincoin-0.1.0.apk --version-name 0.1.0 --version-code 1] \
        [--previous-latest old-latest.json]   # content-only release

Changelog lines come from CHANGELOG.md: the section "## <version>" for the
app, and "## content <content version>" for content (both optional).
Standard library only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
import zipfile
from pathlib import Path

CONTENT_SCHEMA = 1
PACK_FORMAT = 1


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def changelog(section: str, path: Path) -> list[str]:
    if not path.exists():
        return []
    lines, inside = [], False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            inside = line[3:].strip() == section
            continue
        if inside and line.strip().startswith(("-", "*")):
            lines.append(line.strip()[1:].strip())
    return lines


def content_meta(db: Path) -> dict[str, str]:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        meta = dict(con.execute("select key, value from meta"))
        missing = con.execute(
            "select count(*) from sources where attribution = '' or license = ''"
        ).fetchone()[0]
    finally:
        con.close()
    if int(meta.get("schema_version", 0)) != CONTENT_SCHEMA:
        sys.exit(f"content schema {meta.get('schema_version')} != {CONTENT_SCHEMA}")
    if missing:
        sys.exit("content.db has sources without credits")
    return meta


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--content", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--apk", type=Path)
    ap.add_argument("--version-name")
    ap.add_argument("--version-code", type=int)
    ap.add_argument("--min-android-sdk", type=int, default=24)
    ap.add_argument("--min-app-version-code", type=int, default=1)
    ap.add_argument("--previous-latest", type=Path,
                    help="latest.json of the previous release (content-only release)")
    ap.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    a = ap.parse_args(argv)

    a.out.mkdir(parents=True, exist_ok=True)
    base = f"https://github.com/{a.repo}/releases/download/{a.tag}"
    meta = content_meta(a.content)
    cversion = meta["content_version"]
    content_log = changelog(f"content {cversion}", a.changelog)
    manifest = {
        "format": PACK_FORMAT,
        "version": cversion,
        "schemaVersion": CONTENT_SCHEMA,
        "sha256": sha256(a.content),
        "minAppVersionCode": a.min_app_version_code,
        "builtAt": meta.get("built_at"),
        "changelogTh": content_log,
    }
    pack = a.out / f"content-{cversion}.lincoin-content"
    with zipfile.ZipFile(pack, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(a.content, "content.db")
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))

    latest: dict = {
        "content": {
            "version": cversion,
            "url": f"{base}/{pack.name}",
            "sha256": sha256(pack),
            "sizeBytes": pack.stat().st_size,
            "minAppVersionCode": a.min_app_version_code,
            "changelogTh": content_log,
        }
    }
    if a.apk:
        if not (a.version_name and a.version_code):
            sys.exit("--apk needs --version-name and --version-code")
        latest["app"] = {
            "versionCode": a.version_code,
            "versionName": a.version_name,
            "apkUrl": f"{base}/{a.apk.name}",
            "sha256": sha256(a.apk),
            "sizeBytes": a.apk.stat().st_size,
            "minAndroidSdk": a.min_android_sdk,
            "changelogTh": changelog(a.version_name, a.changelog),
        }
    elif a.previous_latest and a.previous_latest.exists():
        prev = json.loads(a.previous_latest.read_text(encoding="utf-8"))
        if "app" in prev:
            latest["app"] = prev["app"]  # keep pointing at the last app build
    (a.out / "latest.json").write_text(
        json.dumps(latest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(latest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
