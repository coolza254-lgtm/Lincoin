#!/usr/bin/env bash
# Puts the latest content build (from the `content-build` branch, produced by
# .github/workflows/content.yml) into app/assets/content/ so it ships inside
# the APK. Run from anywhere inside the repository.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
git -C "$root" fetch --quiet origin content-build
git -C "$root" show origin/content-build:content.db > "$root/app/assets/content/content.db"
git -C "$root" show origin/content-build:SOURCE.txt
python3 - "$root/app/assets/content/content.db" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
meta = dict(db.execute("select key, value from meta"))
open(sys.argv[1].rsplit("/", 1)[0] + "/version.txt", "w").write(meta["content_version"] + "\n")
print("content", meta["content_version"], "schema", meta["schema_version"],
      "words", db.execute("select count(*) from words").fetchone()[0])
PY
