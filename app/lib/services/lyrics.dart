import '../data/catalog.dart';

/// How a conjugated form was reduced to its dictionary form, step by step
/// (shown to the learner, e.g. "รูปปฏิเสธ · รูปอดีต").
enum Inflection {
  polite,
  past,
  te,
  negative,
  want,
  passive,
  causative,
  potential,
  volitional,
  conditional,
  imperative,
  adverb,
  continuing,
}

/// A conjugated form traced back to a dictionary form of [kind].
class Deinflected {
  final String base;

  /// 'v1' (ichidan), 'v5' (godan), 'adj-i', 'vs' (する), 'vk' (来る).
  final String kind;

  /// Outermost step last, e.g. 食べなかった: [negative, past].
  final List<Inflection> steps;
  const Deinflected(this.base, this.kind, this.steps);
}

class _Rule {
  final String from;
  final String to;

  /// Kind of word the result is (what the dictionary entry must be).
  final String toKind;

  /// Kinds this surface can be (the form a further rule produced), or null
  /// for any.
  final Set<String>? fromKinds;
  final Inflection why;
  const _Rule(this.from, this.to, this.toKind, this.why, [this.fromKinds]);
}

/// Godan endings by vowel row: u, i, a, e, o.
const _godan = [
  ['う', 'い', 'わ', 'え', 'お'],
  ['く', 'き', 'か', 'け', 'こ'],
  ['ぐ', 'ぎ', 'が', 'げ', 'ご'],
  ['す', 'し', 'さ', 'せ', 'そ'],
  ['つ', 'ち', 'た', 'て', 'と'],
  ['ぬ', 'に', 'な', 'ね', 'の'],
  ['ぶ', 'び', 'ば', 'べ', 'ぼ'],
  ['む', 'み', 'ま', 'め', 'も'],
  ['る', 'り', 'ら', 'れ', 'ろ'],
];

/// Rules in the style of Yomichan's deinflector, trimmed to the common
/// forms in songs. A result of kind 'adj-i' can be reduced again (ない,
/// たい and adjectives conjugate alike).
final List<_Rule> _rules = () {
  final r = <_Rule>[];
  void add(
    String from,
    String to,
    String kind,
    Inflection why, [
    Set<String>? fromKinds,
  ]) => r.add(_Rule(from, to, kind, why, fromKinds));

  // い-adjectives (also ない / たい / そう forms reduced to them).
  add('かった', 'い', 'adj-i', Inflection.past);
  add('くて', 'い', 'adj-i', Inflection.te);
  add('く', 'い', 'adj-i', Inflection.adverb);
  add('ければ', 'い', 'adj-i', Inflection.conditional);
  add('くない', 'い', 'adj-i', Inflection.negative);
  // Polite endings reduce to the stem form handled below.
  add('ました', 'ます', 'masu', Inflection.past);
  add('ません', 'ます', 'masu', Inflection.negative);
  add('ませんでした', 'ます', 'masu', Inflection.negative);
  add('ましょう', 'ます', 'masu', Inflection.volitional);

  // Ichidan (食べる).
  for (final (from, why) in [
    ('ます', Inflection.polite),
    ('た', Inflection.past),
    ('て', Inflection.te),
    ('ない', Inflection.negative),
    ('たい', Inflection.want),
    ('られる', Inflection.passive),
    ('させる', Inflection.causative),
    ('よう', Inflection.volitional),
    ('れば', Inflection.conditional),
    ('ろ', Inflection.imperative),
    ('ず', Inflection.negative),
    ('ながら', Inflection.continuing),
  ]) {
    final kinds = switch (from) {
      'ます' => {'masu'},
      'ない' || 'たい' => {'adj-i'},
      'られる' || 'させる' => {'v1'},
      _ => null,
    };
    add(from, 'る', 'v1', why, kinds);
  }
  // Godan (書く, 飲む, 歌う …).
  for (final row in _godan) {
    final (u, i, a, e, o) = (row[0], row[1], row[2], row[3], row[4]);
    add('$iます', u, 'v5', Inflection.polite, {'masu'});
    add('$iたい', u, 'v5', Inflection.want, {'adj-i'});
    add('$iながら', u, 'v5', Inflection.continuing);
    add('$aない', u, 'v5', Inflection.negative, {'adj-i'});
    add('$aず', u, 'v5', Inflection.negative);
    add('$aれる', u, 'v5', Inflection.passive, {'v1'});
    add('$aせる', u, 'v5', Inflection.causative, {'v1'});
    add('$eる', u, 'v5', Inflection.potential, {'v1'});
    add('$eば', u, 'v5', Inflection.conditional);
    add(e, u, 'v5', Inflection.imperative);
    add('$oう', u, 'v5', Inflection.volitional);
  }
  // Te / ta forms of godan verbs.
  for (final (te, ta, u) in [
    ('って', 'った', 'う'),
    ('って', 'った', 'つ'),
    ('って', 'った', 'る'),
    ('いて', 'いた', 'く'),
    ('いで', 'いだ', 'ぐ'),
    ('して', 'した', 'す'),
    ('んで', 'んだ', 'ぬ'),
    ('んで', 'んだ', 'ぶ'),
    ('んで', 'んだ', 'む'),
  ]) {
    add(te, u, 'v5', Inflection.te);
    add(ta, u, 'v5', Inflection.past);
  }
  // 行く is irregular: 行って / 行った.
  add('行って', '行く', 'v5', Inflection.te);
  add('行った', '行く', 'v5', Inflection.past);
  add('いって', 'いく', 'v5', Inflection.te);
  add('いった', 'いく', 'v5', Inflection.past);
  // する and 来る.
  for (final (from, why) in [
    ('します', Inflection.polite),
    ('した', Inflection.past),
    ('して', Inflection.te),
    ('しない', Inflection.negative),
    ('したい', Inflection.want),
    ('される', Inflection.passive),
    ('させる', Inflection.causative),
    ('しよう', Inflection.volitional),
    ('すれば', Inflection.conditional),
    ('できる', Inflection.potential),
    ('しろ', Inflection.imperative),
  ]) {
    add(from, 'する', 'vs', why);
  }
  for (final (from, why) in [
    ('きます', Inflection.polite),
    ('きた', Inflection.past),
    ('きて', Inflection.te),
    ('こない', Inflection.negative),
    ('きたい', Inflection.want),
    ('こよう', Inflection.volitional),
    ('くれば', Inflection.conditional),
    ('こられる', Inflection.potential),
    ('こい', Inflection.imperative),
  ]) {
    add(from, 'くる', 'vk', why);
  }
  for (final (from, why) in [
    ('来ます', Inflection.polite),
    ('来た', Inflection.past),
    ('来て', Inflection.te),
    ('来ない', Inflection.negative),
    ('来たい', Inflection.want),
    ('来よう', Inflection.volitional),
    ('来れば', Inflection.conditional),
    ('来られる', Inflection.potential),
    ('来い', Inflection.imperative),
  ]) {
    add(from, '来る', 'vk', why);
  }
  return r;
}();

/// Every dictionary form [surface] could come from (the surface itself
/// first, as kind null). Up to three steps deep (食べられなかった).
List<Deinflected> deinflect(String surface) {
  final out = <Deinflected>[Deinflected(surface, '', const [])];
  final seen = <String>{};
  var frontier = [out.first];
  for (var depth = 0; depth < 3 && frontier.isNotEmpty; depth++) {
    final next = <Deinflected>[];
    for (final d in frontier) {
      for (final rule in _rules) {
        if (!d.base.endsWith(rule.from)) continue;
        if (d.steps.isNotEmpty &&
            rule.fromKinds != null &&
            !rule.fromKinds!.contains(d.kind)) {
          continue;
        }
        final base =
            d.base.substring(0, d.base.length - rule.from.length) + rule.to;
        if (base.isEmpty) continue;
        final key = '$base|${rule.toKind}';
        if (!seen.add(key)) continue;
        final n = Deinflected(base, rule.toKind, [rule.why, ...d.steps]);
        out.add(n);
        next.add(n);
      }
    }
    frontier = next;
  }
  return out;
}

bool _kindMatches(String kind, List<String> pos) => switch (kind) {
  '' => true,
  'v1' => pos.any((p) => p == 'v1' || p.startsWith('v1-')),
  'v5' => pos.any((p) => p.startsWith('v5')),
  'adj-i' => pos.contains('adj-i') || pos.contains('adj-ix'),
  'vs' => pos.any((p) => p.startsWith('vs')),
  'vk' => pos.contains('vk'),
  _ => false,
};

/// Particles and grammar words that are not vocabulary items, with a Thai
/// note. Only used when the dictionary has no entry.
const grammarWords = <String, String>{
  'は': 'คำชี้หัวเรื่อง (อ่านว่า วะ)',
  'が': 'คำชี้ประธาน',
  'を': 'คำชี้กรรม (อ่านว่า โอะ)',
  'に': 'ที่ / ไปยัง / แก่ (บอกจุดหมาย เวลา ผู้รับ)',
  'で': 'ที่ / ด้วย (บอกสถานที่ทำ วิธีการ)',
  'へ': 'ไปทาง (อ่านว่า เอะ)',
  'と': 'กับ / และ / ว่า (อ้างคำพูด)',
  'も': 'ก็ / ด้วย',
  'の': 'ของ / ที่ (เชื่อมคำนาม)',
  'や': 'และ (ยกตัวอย่าง)',
  'か': 'ไหม / หรือ (คำถาม)',
  'よ': 'นะ (ย้ำ บอกให้รู้)',
  'ね': 'นะ / เนอะ (ขอความเห็นด้วย)',
  'な': 'นะ / อย่า… (ท้ายกริยา = ห้าม)',
  'わ': 'นะ (ท้ายประโยค โทนนุ่ม)',
  'ぞ': 'นะ! (ย้ำแรง โทนผู้ชาย)',
  'さ': 'นะ / น่ะ (ภาษาพูด)',
  'から': 'จาก / เพราะว่า',
  'まで': 'จนถึง',
  'より': 'กว่า / จาก',
  'けど': 'แต่',
  'けれど': 'แต่',
  'だけ': 'แค่ / เท่านั้น',
  'しか': 'แค่… (ตามด้วยปฏิเสธ)',
  'って': 'ว่า / ที่เรียกว่า (ภาษาพูด)',
  'ばかり': 'แต่… / เพิ่งจะ',
  'ほど': 'ถึงขนาด / ประมาณ',
  'など': 'เป็นต้น',
  'でも': 'แต่ / แม้แต่',
  'だ': 'เป็น / คือ (ภาษาพูดของ です)',
  'です': 'เป็น / คือ (สุภาพ)',
  'だった': 'เป็น… (อดีต)',
  'でした': 'เป็น… (อดีต สุภาพ)',
  'じゃない': 'ไม่ใช่',
  'ない': 'ไม่ / ไม่มี',
  'たい': 'อยาก…',
  'ている': 'กำลัง… / อยู่ในสภาพ…',
  'てる': 'กำลัง… (ภาษาพูดของ ている)',
  'いる': 'อยู่ / มี (สิ่งมีชีวิต)',
  'ある': 'มี / อยู่ (สิ่งของ)',
  'こと': 'เรื่อง / การ…',
  'もの': 'สิ่ง / ของ',
  'ように': 'เพื่อให้ / ให้…ได้',
  'まま': 'ทั้งอย่างนั้น / คงสภาพ',
  'のに': 'ทั้งที่…',
};

/// One piece of a lyric line.
class LyricToken {
  final String text;

  /// Vocabulary match (with how the surface was conjugated).
  final WordStudy? word;
  final List<Inflection> steps;

  /// Particle or grammar word with a built-in note.
  final String? grammar;

  /// Spaces and punctuation: shown, not tappable.
  final bool isGap;
  const LyricToken(
    this.text, {
    this.word,
    this.steps = const [],
    this.grammar,
    this.isGap = false,
  });

  /// Something to look up when tapped.
  bool get isWord => !isGap;
  bool get known => word != null || grammar != null;
}

bool _isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || c == 0x3005;
bool _isHiragana(int c) => c >= 0x3041 && c <= 0x309F;
bool _isKatakana(int c) => (c >= 0x30A0 && c <= 0x30FF) || c == 0x30FC;
bool _isJapanese(int c) => _isKanji(c) || _isHiragana(c) || _isKatakana(c);

/// Splits lyrics into words by longest match against the vocabulary (all
/// written forms, with conjugations traced back), then particles; what is
/// left groups into runs of the same script.
class LyricsTokenizer {
  final Map<String, List<WordStudy>> _forms = {};
  int _maxLen = 1;

  LyricsTokenizer(Catalog catalog) {
    for (final i in catalog.itemsOf(vocabDeck)) {
      if (i is! WordStudy) continue;
      for (final f in i.word.forms) {
        _forms.putIfAbsent(f.text, () => []).add(i);
        if (f.text.length > _maxLen) _maxLen = f.text.length;
      }
    }
  }

  /// Words written as [text] (for the learner's own lookups).
  List<WordStudy> lookup(String text) => _forms[text] ?? const [];

  /// The best vocabulary match starting at [line]'s [start], longest first.
  (int, WordStudy, List<Inflection>)? _match(String line, int start) {
    final maxEnd = (start + _maxLen + 6).clamp(0, line.length);
    for (var end = maxEnd; end > start; end--) {
      final s = line.substring(start, end);
      if (!_isJapanese(s.codeUnitAt(s.length - 1))) continue;
      for (final d in deinflect(s)) {
        for (final w in _forms[d.base] ?? const <WordStudy>[]) {
          if (!_kindMatches(d.kind, w.word.pos)) continue;
          // A lone kana matching a long word's kana form is usually a
          // particle (e.g. は), handled below.
          if (s.length == 1 &&
              _isHiragana(s.codeUnitAt(0)) &&
              d.steps.isEmpty) {
            continue;
          }
          return (end, w, d.steps);
        }
      }
    }
    return null;
  }

  List<LyricToken> tokenize(String line) {
    final out = <LyricToken>[];
    var i = 0;
    while (i < line.length) {
      final c = line.codeUnitAt(i);
      if (!_isJapanese(c)) {
        var j = i + 1;
        while (j < line.length && !_isJapanese(line.codeUnitAt(j))) {
          j++;
        }
        out.add(LyricToken(line.substring(i, j), isGap: true));
        i = j;
        continue;
      }
      // Grammar words first when they are kana (は, から, って …), but a
      // longer vocabulary match wins (はな = 花 is not は + な).
      final m = _match(line, i);
      String? g;
      for (var len = 4; len >= 1; len--) {
        if (i + len > line.length) continue;
        final s = line.substring(i, i + len);
        if (grammarWords.containsKey(s)) {
          g = s;
          break;
        }
      }
      if (m != null && (g == null || m.$1 - i > g.length)) {
        out.add(LyricToken(line.substring(i, m.$1), word: m.$2, steps: m.$3));
        i = m.$1;
        continue;
      }
      if (g != null) {
        out.add(LyricToken(g, grammar: grammarWords[g]));
        i += g.length;
        continue;
      }
      // Unknown: a run of kanji (with the kana that follows it), of
      // hiragana or of katakana is one word, up to a particle or a known
      // word.
      var j = i + 1;
      if (_isKanji(c)) {
        while (j < line.length && _isKanji(line.codeUnitAt(j))) {
          j++;
        }
        while (j < line.length &&
            _isHiragana(line.codeUnitAt(j)) &&
            !grammarWords.containsKey(line[j]) &&
            _match(line, j) == null) {
          j++;
        }
      } else if (_isHiragana(c)) {
        while (j < line.length &&
            _isHiragana(line.codeUnitAt(j)) &&
            !grammarWords.containsKey(line[j]) &&
            _match(line, j) == null) {
          j++;
        }
      } else if (_isKatakana(c)) {
        while (j < line.length && _isKatakana(line.codeUnitAt(j))) {
          j++;
        }
      }
      out.add(LyricToken(line.substring(i, j)));
      i = j;
    }
    return out;
  }
}
