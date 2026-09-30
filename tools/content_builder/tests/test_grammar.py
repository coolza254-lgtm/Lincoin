import json
import re
import tempfile
import unittest
from pathlib import Path

from lincoin_content import grammar


class GrammarSourceTest(unittest.TestCase):
    def test_real_n5_file_is_valid(self):
        points = grammar.load_points(5)
        self.assertGreaterEqual(len(points), 40)
        self.assertEqual(len({p.id for p in points}), len(points))
        for p in points:
            self.assertRegex(p.id, r"^g:n5\.\d{3}$")
            for field in (p.title_th, p.meaning_th):
                self.assertRegex(field, r"[฀-๿]", p.id)
            self.assertTrue(p.patterns, p.id)

    def test_similar_ids_must_exist(self):
        d = Path(tempfile.mkdtemp())
        (d / "n5.json").write_text(json.dumps([{
            "id": "g:n5.001", "level": 5, "ord": 1, "title_ja": "x", "title_th": "ก",
            "meaning_th": "ก", "formation_th": "ก", "similar": ["g:n5.099"],
            "patterns": [{"regex": "(を)"}], "wrong": ["に", "で"]}]))
        with self.assertRaises(ValueError):
            grammar.load_points(5, d)


class FindExamplesTest(unittest.TestCase):
    def point(self, regex, wrong=("に", "で", "の", "を"), group=1):
        return grammar.Point("g:n5.001", 5, 1, "〜を", "ก", "ก", "ก", None, [],
                             [(re.compile(regex), group)], list(wrong))

    def test_blank_once_easy_first_and_limits(self):
        sents = {
            1: "本を読みます。",
            2: "難解な論文を読む。",            # unknown kanji → later
            3: "水を飲んで、本を読みます。",    # answer appears twice → skipped
            4: "私は学生です。",                # no match
            5: "とても長い長い長い長い長い文章をゆっくり読みます。",  # too long
        }
        known = set("本読水飲私学生")
        out = grammar.find_examples([self.point("(を)")], sents, known)["g:n5.001"]
        self.assertEqual([m.sentence_id for m in out], [1, 2])
        m = out[0]
        self.assertEqual(sents[1][m.start:m.end], "を")
        self.assertEqual(m.answer, "を")
        self.assertNotIn("を", m.wrong)
        self.assertEqual(len(m.wrong), 3)

    def test_group_and_exclusions(self):
        sents = {1: "昨日は寒かったです。", 2: "今日は暑かったです。"}
        p = self.point(r"(寒|暑)(かった)", wrong=["い", "くない"], group=2)
        out = grammar.find_examples([p], sents, set("昨日寒今暑"), {"g:n5.001": {2}})
        self.assertEqual([m.sentence_id for m in out["g:n5.001"]], [1])
        self.assertEqual(out["g:n5.001"][0].answer, "かった")


if __name__ == "__main__":
    unittest.main()
