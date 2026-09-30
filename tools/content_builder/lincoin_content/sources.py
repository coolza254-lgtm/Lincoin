"""Source registry and downloader.

Every dataset comes from sources.json, which also carries its licence and
attribution text. Downloads are cached with their SHA-256 so a build records
exactly which files it used.
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import time
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES_JSON = ROOT / "sources.json"


@dataclass
class Source:
    id: str
    name: str
    homepage: str
    license: str
    license_url: str
    attribution: str
    files: dict = field(default_factory=dict)
    version: str | None = None


def load_sources(path: Path = SOURCES_JSON) -> dict[str, Source]:
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for raw in data["sources"]:
        s = Source(**raw)
        missing = [k for k in ("license", "license_url", "attribution") if not getattr(s, k)]
        if missing:
            raise ValueError(f"source {s.id} is missing {missing}")
        out[s.id] = s
    return out


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _download(url: str, dest: Path, attempts: int = 4) -> None:
    tmp = dest.with_suffix(dest.suffix + ".part")
    for i in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "lincoin-content-builder"})
            with urllib.request.urlopen(req, timeout=120) as r, tmp.open("wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            tmp.replace(dest)
            return
        except Exception as e:  # noqa: BLE001 - retried, then re-raised
            if i == attempts - 1:
                raise RuntimeError(f"download failed: {url}: {e}") from e
            time.sleep(2 ** (i + 1))


class Cache:
    """Local copies of source files plus a manifest of what was fetched."""

    def __init__(self, directory: Path):
        self.dir = Path(directory)
        self.dir.mkdir(parents=True, exist_ok=True)
        self.manifest_path = self.dir / "manifest.json"
        self.manifest = (
            json.loads(self.manifest_path.read_text()) if self.manifest_path.exists() else {}
        )

    def path(self, source_id: str, key: str) -> Path:
        entry = self.manifest.get(f"{source_id}/{key}")
        if not entry:
            raise FileNotFoundError(f"{source_id}/{key} not fetched; run fetch first")
        return self.dir / entry["file"]

    def has(self, source_id: str, key: str) -> bool:
        return f"{source_id}/{key}" in self.manifest

    def fetch(self, source: Source, key: str, force: bool = False) -> Path:
        urls = source.files[key]
        urls = urls if isinstance(urls, list) else [urls]
        manifest_key = f"{source.id}/{key}"
        if not force and manifest_key in self.manifest:
            p = self.dir / self.manifest[manifest_key]["file"]
            if p.exists():
                return p
        errors = []
        for url in urls:
            name = f"{source.id}__{key}__{os.path.basename(url.split('?')[0])}"
            dest = self.dir / name
            try:
                _download(url, dest)
            except RuntimeError as e:
                errors.append(str(e))
                continue
            self.manifest[manifest_key] = {
                "file": name,
                "url": url,
                "sha256": _sha256(dest),
                "bytes": dest.stat().st_size,
                "retrieved_at": _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds"),
            }
            self.manifest_path.write_text(json.dumps(self.manifest, indent=2))
            return dest
        raise RuntimeError("; ".join(errors))

    def record(self, source_id: str, key: str) -> dict:
        return self.manifest.get(f"{source_id}/{key}", {})
