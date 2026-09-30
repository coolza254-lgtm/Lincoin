/// Romaji → hiragana conversion and reading comparison for typed answers.
///
/// Accepts Hepburn, Kunrei and common IME (wapuro) spellings, so the learner
/// can answer without a Japanese keyboard.
library;

const Map<String, String> _table = {
  // vowels
  'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
  // k g
  'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
  'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
  // s z
  'sa': 'さ', 'shi': 'し', 'si': 'し', 'su': 'す', 'se': 'せ', 'so': 'そ',
  'za': 'ざ', 'ji': 'じ', 'zi': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
  // t d
  'ta': 'た', 'chi': 'ち', 'ti': 'ち', 'tsu': 'つ', 'tu': 'つ', 'te': 'て', 'to': 'と',
  'da': 'だ', 'di': 'ぢ', 'du': 'づ', 'de': 'で', 'do': 'ど',
  // n h b p m
  'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
  'ha': 'は', 'hi': 'ひ', 'fu': 'ふ', 'hu': 'ふ', 'he': 'へ', 'ho': 'ほ',
  'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
  'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
  'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
  // y r w
  'ya': 'や', 'yu': 'ゆ', 'yo': 'よ', 'ye': 'いぇ',
  'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
  'wa': 'わ', 'wo': 'を', 'wi': 'うぃ', 'we': 'うぇ',
  // palatalised (yōon)
  'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
  'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
  'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ', 'she': 'しぇ',
  'sya': 'しゃ', 'syu': 'しゅ', 'syo': 'しょ',
  'ja': 'じゃ', 'ju': 'じゅ', 'jo': 'じょ', 'je': 'じぇ',
  'jya': 'じゃ', 'jyu': 'じゅ', 'jyo': 'じょ',
  'zya': 'じゃ', 'zyu': 'じゅ', 'zyo': 'じょ',
  'cha': 'ちゃ', 'chu': 'ちゅ', 'cho': 'ちょ', 'che': 'ちぇ',
  'tya': 'ちゃ', 'tyu': 'ちゅ', 'tyo': 'ちょ',
  'cya': 'ちゃ', 'cyu': 'ちゅ', 'cyo': 'ちょ',
  'dya': 'ぢゃ', 'dyu': 'ぢゅ', 'dyo': 'ぢょ',
  'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
  'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
  'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
  'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
  'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
  'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
  // extended (loanwords)
  'fa': 'ふぁ', 'fi': 'ふぃ', 'fe': 'ふぇ', 'fo': 'ふぉ', 'fyu': 'ふゅ',
  'va': 'ゔぁ', 'vi': 'ゔぃ', 'vu': 'ゔ', 've': 'ゔぇ', 'vo': 'ゔぉ',
  'thi': 'てぃ', 'thu': 'てゅ', 'dhi': 'でぃ', 'dhu': 'でゅ',
  'twu': 'とぅ', 'dwu': 'どぅ',
  'tsa': 'つぁ', 'tsi': 'つぃ', 'tse': 'つぇ', 'tso': 'つぉ',
  // explicit small kana
  'xa': 'ぁ', 'xi': 'ぃ', 'xu': 'ぅ', 'xe': 'ぇ', 'xo': 'ぉ',
  'la': 'ぁ', 'li': 'ぃ', 'lu': 'ぅ', 'le': 'ぇ', 'lo': 'ぉ',
  'xya': 'ゃ', 'xyu': 'ゅ', 'xyo': 'ょ', 'lya': 'ゃ', 'lyu': 'ゅ', 'lyo': 'ょ',
  'xtu': 'っ', 'ltu': 'っ', 'xtsu': 'っ', 'ltsu': 'っ', 'xwa': 'ゎ', 'lwa': 'ゎ',
  '-': 'ー',
};

bool _isVowel(String c) => c.length == 1 && 'aiueo'.contains(c);
bool _isAsciiLetter(String c) =>
    c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A;

/// Converts romaji in [input] to hiragana; characters that are not romaji
/// (kana, kanji, punctuation) pass through unchanged.
String romajiToHiragana(String input) {
  final s = input.toLowerCase();
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';

    if (c == 'n') {
      if (next == "'") {
        out.write('ん');
        i += 2;
        continue;
      }
      if (next == 'n') {
        // "nn" is ん; the second n starts the next syllable only when a
        // vowel or y follows it (IME behaviour: konnichiha → こんにちは).
        final after = i + 2 < s.length ? s[i + 2] : '';
        out.write('ん');
        i += (_isVowel(after) || after == 'y') ? 1 : 2;
        continue;
      }
      if (next.isEmpty || !(_isVowel(next) || next == 'y')) {
        out.write('ん');
        i += 1;
        continue;
      }
    }

    // Doubled consonant → small tsu (kk, ss, tt, pp …; "tch" as in matcha).
    if (_isAsciiLetter(c) &&
        !_isVowel(c) &&
        c != 'n' &&
        (next == c || (c == 't' && next == 'c'))) {
      out.write('っ');
      i += 1;
      continue;
    }

    var matched = false;
    for (var len = 4; len >= 1; len--) {
      if (i + len > s.length) continue;
      final kana = _table[s.substring(i, i + len)];
      if (kana != null) {
        out.write(kana);
        i += len;
        matched = true;
        break;
      }
    }
    if (!matched) {
      out.write(c);
      i += 1;
    }
  }
  return out.toString();
}

/// Katakana → hiragana; the long-vowel mark ー is kept.
String katakanaToHiragana(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30A1 && rune <= 0x30F6) {
      out.writeCharCode(rune - 0x60);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Canonical form for comparing readings: hiragana, no whitespace, and the
/// long-vowel mark written out as a vowel (コーヒー ≡ "koohii").
String normalizeReading(String input) =>
    _expandLongVowels(katakanaToHiragana(romajiToHiragana(input.trim()))
        .replaceAll(RegExp(r'[\s　]'), ''));

/// Vowel row of each hiragana, for replacing ー with the preceding vowel.
const Map<String, String> _vowelOf = {
  'a': 'あかがさざただなはばぱまやゃらわゎぁ',
  'i': 'いきぎしじちぢにひびぴみりぃ',
  'u': 'うくぐすずつづぬふぶぷむゆゅるぅゔ',
  'e': 'えけげせぜてでねへべぺめれぇ',
  'o': 'おこごそぞとどのほぼぽもよょろをぉ',
};
const Map<String, String> _vowelKana = {
  'a': 'あ',
  'i': 'い',
  'u': 'う',
  'e': 'え',
  'o': 'お'
};

String _expandLongVowels(String s) {
  if (!s.contains('ー')) return s;
  final out = StringBuffer();
  String? prev;
  for (final ch in s.split('')) {
    if (ch == 'ー' && prev != null) {
      final v = _vowelOf.entries
          .where((e) => e.value.contains(prev!))
          .map((e) => e.key)
          .firstOrNull;
      final kana = v == null ? ch : _vowelKana[v]!;
      out.write(kana);
      prev = kana;
      continue;
    }
    out.write(ch);
    prev = ch;
  }
  return out.toString();
}

/// True when [input] (romaji or kana) equals any of [accepted] readings.
bool readingMatches(String input, Iterable<String> accepted) {
  final given = normalizeReading(input);
  if (given.isEmpty) return false;
  return accepted.any((r) => normalizeReading(r) == given);
}
