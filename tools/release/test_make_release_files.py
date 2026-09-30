import json
import sqlite3
import tempfile
import unittest
import zipfile
from pathlib import Path

import make_release_files as m


class ReleaseFilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        db = self.tmp / "content.db"
        con = sqlite3.connect(db)
        con.execute("create table meta (key text primary key, value text)")
        con.execute("create table sources (id text, attribution text, license text)")
        con.executemany("insert into meta values (?, ?)",
                        [("schema_version", "1"), ("content_version", "2026.10.1")])
        con.execute("insert into sources values ('a', 'credit', 'CC BY-SA 4.0')")
        con.commit()
        con.close()
        self.db = db
        (self.tmp / "CHANGELOG.md").write_text(
            "# Changelog\n\n## 0.2.0\n- เพิ่มโหมดฝึก\n\n## content 2026.10.1\n- แก้คำแปล\n",
            encoding="utf-8")
        self.apk = self.tmp / "lincoin-0.2.0.apk"
        self.apk.write_bytes(b"apk")

    def run_tool(self, *extra):
        out = self.tmp / "dist"
        m.main(["--content", str(self.db), "--out", str(out), "--repo", "o/r",
                "--tag", "v0.2.0", "--changelog", str(self.tmp / "CHANGELOG.md"),
                *extra])
        return out, json.loads((out / "latest.json").read_text(encoding="utf-8"))

    def test_app_and_content(self):
        out, latest = self.run_tool("--apk", str(self.apk), "--version-name", "0.2.0",
                                    "--version-code", "5")
        self.assertEqual(latest["app"]["versionCode"], 5)
        self.assertEqual(latest["app"]["changelogTh"], ["เพิ่มโหมดฝึก"])
        self.assertEqual(latest["app"]["sha256"], m.sha256(self.apk))
        self.assertTrue(latest["app"]["apkUrl"].endswith("/v0.2.0/lincoin-0.2.0.apk"))
        pack = out / "content-2026.10.1.lincoin-content"
        with zipfile.ZipFile(pack) as z:
            manifest = json.loads(z.read("manifest.json"))
            self.assertEqual(manifest["sha256"], m.sha256(self.db))
            self.assertEqual(z.read("content.db"), self.db.read_bytes())
        self.assertEqual(latest["content"]["sha256"], m.sha256(pack))
        self.assertEqual(latest["content"]["changelogTh"], ["แก้คำแปล"])

    def test_content_only_keeps_previous_app(self):
        prev = self.tmp / "prev.json"
        prev.write_text(json.dumps({"app": {"versionCode": 4}}))
        _, latest = self.run_tool("--previous-latest", str(prev))
        self.assertEqual(latest["app"], {"versionCode": 4})


if __name__ == "__main__":
    unittest.main()
