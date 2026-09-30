import bz2
import gzip
import io
import json
import shutil
import sqlite3
import tarfile
import tempfile
import unittest
from pathlib import Path

from lincoin_content.build import build
from lincoin_content.checks import check
from lincoin_content.credits import credits_markdown
from lincoin_content.jmdict import created_date, read_entries
from lincoin_content.kana import kana_rows
from lincoin_content.readers import parse_index_line
from lincoin_content.sources import Cache, load_sources

FIX = Path(__file__).parent / "fixtures"


def make_cache(tmp: Path, n5: Path = FIX / "n5.csv") -> Cache:
    """A cache whose manifest points at fixtures, compressed the same way as
    the real downloads (gzip, bz2, tar.bz2)."""
    d = tmp / "cache"
    d.mkdir()
    files = {}

    def put(sid, key, name, data: bytes):
        (d / name).write_bytes(data)
        files[f"{sid}/{key}"] = {"file": name, "url": f"fixture://{name}", "sha256": "0" * 64,
                                 "bytes": len(data), "retrieved_at": "2026-09-30T00:00:00+00:00"}

    def tar_bz2(member: str, data: bytes) -> bytes:
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w:bz2") as t:
            info = tarfile.TarInfo(member)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
        return buf.getvalue()

    put("jmdict", "jmdict", "JMdict_e.gz", gzip.compress((FIX / "JMdict_e.xml").read_bytes()))
    put("jlpt_jmdict_match", "n5", "n5.csv", n5.read_bytes())
    put("jlpt_jmdict_match", "n4", "n4.csv", (FIX / "n4.csv").read_bytes())
    put("jmdict_furigana", "furigana", "JmdictFurigana.json.gz",
        gzip.compress((FIX / "JmdictFurigana.json").read_bytes()))
    put("tatoeba", "jpn_sentences", "jpn_sentences_detailed.tsv.bz2",
        bz2.compress((FIX / "jpn_sentences_detailed.tsv").read_bytes()))
    put("tatoeba", "eng_sentences", "eng_sentences_detailed.tsv.bz2",
        bz2.compress((FIX / "eng_sentences_detailed.tsv").read_bytes()))
    put("tatoeba", "jpn_eng_links", "jpn-eng_links.tsv.bz2", bz2.compress((FIX / "jpn-eng_links.tsv").read_bytes()))
    put("tatoeba", "jpn_indices", "jpn_indices.tar.bz2",
        tar_bz2("jpn_indices.csv", (FIX / "jpn_indices.csv").read_bytes()))
    put("tatoeba", "cc0", "sentences_CC0.tar.bz2", tar_bz2("sentences_CC0.csv", (FIX / "sentences_CC0.csv").read_bytes()))
    (d / "manifest.json").write_text(json.dumps(files))
    return Cache(d)


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        cls.cache = make_cache(cls.tmp)
        cls.out = cls.tmp / "content.db"
        cls.report = build(cls.cache, cls.out, ["n5", "n4"])
        cls.db = sqlite3.connect(cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        shutil.rmtree(cls.tmp)

    def q(self, sql, *args):
        return self.db.execute(sql, args).fetchall()

    def test_checks_pass(self):
        self.assertEqual(check(self.out, self.report), [])

    def test_words_and_levels(self):
        self.assertEqual(self.report.words, 5)
        self.assertEqual(self.q("SELECT jlpt_level FROM words WHERE id='w:2000001'"), [(5,)])
        self.assertEqual(self.report.duplicates_across_levels, [2000001])

    def test_order_prefers_frequent_words(self):
        order = [r[0] for r in self.q("SELECT id FROM words WHERE jlpt_level=5 ORDER BY order_in_level")]
        self.assertEqual(order[:2], ["w:2000001", "w:1198180"])  # nf02, nf04

    def test_entities_and_pos_inheritance(self):
        rows = self.q("SELECT ord, pos, gloss_en, restricted_to, th_status FROM senses "
                      "WHERE word_id='w:1198180' ORDER BY ord")
        self.assertEqual(json.loads(rows[0][1]), ["v5u", "vi"])
        self.assertEqual(json.loads(rows[1][1]), ["v5u", "vi"])
        self.assertEqual(rows[0][2], "to meet; to encounter")
        self.assertEqual(rows[1][2], "to have an accident & such")
        self.assertEqual(json.loads(rows[1][3]), ["会う"])
        self.assertEqual(rows[0][4], "missing")

    def test_kana_word_has_no_primary_kanji(self):
        self.assertEqual(self.q("SELECT COUNT(*) FROM word_forms WHERE word_id='w:1000002' "
                                "AND kind='kanji' AND is_primary=1"), [(0,)])
        self.assertEqual(json.loads(self.q("SELECT tags FROM words WHERE id='w:1000002'")[0][0]), ["uk", "common"])

    def test_search_only_reading_not_accepted(self):
        rows = dict(self.q("SELECT text, accept_as_answer FROM word_forms WHERE word_id='w:1000005' AND kind='kana'"))
        self.assertEqual(rows, {"あかい": 1, "アカイ": 0})

    def test_furigana(self):
        fg = self.q("SELECT furigana_json FROM word_forms WHERE word_id='w:2000001' AND kind='kanji'")[0][0]
        self.assertEqual(json.loads(fg)[1], {"ruby": "書", "rt": "しょ"})

    def test_examples_selection(self):
        ex = self.q("SELECT word_id, example_id, rank, verified FROM word_examples ORDER BY word_id, rank")
        by_word = {}
        for w, e, r, v in ex:
            by_word.setdefault(w, []).append((e, v))
        # Verified, short example first; long one second.
        self.assertEqual(by_word["w:2000001"], [("ex:100", 1), ("ex:104", 0)])
        # Sentence without author (103) is skipped.
        self.assertEqual(by_word["w:1198180"], [("ex:101", 1)])
        # Homograph 方: explicit reading accepted, bare 方 (105) rejected.
        self.assertEqual(by_word["w:1000003"], [("ex:102", 0)])
        self.assertGreater(self.report.skipped_sentences_without_author, 0)

    def test_example_licences_and_authors(self):
        rows = {r[0]: r[1:] for r in self.q("SELECT id, ja_author, en_author, ja_license, en_license FROM examples")}
        self.assertEqual(rows["ex:101"], ("userB", "userF", "CC0 1.0", "CC0 1.0"))
        self.assertEqual(rows["ex:100"], ("userA", "userE", "CC BY 2.0 FR", "CC BY 2.0 FR"))

    def test_sources_and_credits(self):
        ids = {r[0] for r in self.q("SELECT id FROM sources")}
        self.assertEqual(ids, {"jmdict", "jmdict_furigana", "jlpt_tanos", "jlpt_jmdict_match", "tatoeba", "lincoin"})
        self.assertEqual(self.q("SELECT version FROM sources WHERE id='jmdict'"), [("2026-09-29",)])
        md = credits_markdown(self.out)
        for s in load_sources().values():
            self.assertIn(s.attribution, md)

    def test_kana_table(self):
        self.assertEqual(self.q("SELECT COUNT(*) FROM kana"), [(208,)])
        self.assertEqual(self.q("SELECT char, romaji FROM kana WHERE id='k:kata.kya'"), [("キャ", "kya")])
        self.assertEqual(self.q("SELECT char FROM kana WHERE id='k:hira.ji_d'"), [("ぢ",)])


class FailureTest(unittest.TestCase):
    def test_missing_jmdict_entry_fails_checks(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            bad = tmp / "n5.csv"
            bad.write_text((FIX / "n5.csv").read_text() + "9999999,なし,無し,none\n", encoding="utf-8")
            cache = make_cache(tmp, n5=bad)
            out = tmp / "c.db"
            report = build(cache, out, ["n5"], with_examples=False)
            errors = check(out, report)
            self.assertTrue(any("not found in JMdict" in e for e in errors), errors)
        finally:
            shutil.rmtree(tmp)

    def test_source_without_licence_is_rejected(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            p = tmp / "s.json"
            p.write_text(json.dumps({"sources": [{"id": "x", "name": "x", "homepage": "h", "license": "",
                                                  "license_url": "u", "attribution": "a"}]}))
            with self.assertRaises(ValueError):
                load_sources(p)
        finally:
            shutil.rmtree(tmp)


class UnitTest(unittest.TestCase):
    def test_index_tokens(self):
        self.assertEqual(parse_index_line("図書館(としょかん){図書館}~ で 読む[01]{読みます}"),
                         [("図書館", "としょかん", True), ("で", None, False), ("読む", None, False)])

    def test_jmdict_reader(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            p = tmp / "j.gz"
            p.write_bytes(gzip.compress((FIX / "JMdict_e.xml").read_bytes()))
            entries, counts = read_entries(p, {1000003})
            self.assertEqual(list(entries), [1000003])
            self.assertEqual(counts["方"], 2)
            self.assertEqual(created_date(p), "2026-09-29")
        finally:
            shutil.rmtree(tmp)

    def test_kana_ids_unique(self):
        ids = [k["id"] for k in kana_rows()]
        self.assertEqual(len(ids), len(set(ids)))


if __name__ == "__main__":
    unittest.main()
