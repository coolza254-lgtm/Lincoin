import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/services/lyrics.dart';

import '../support/fixture.dart';

void main() {
  late LyricsTokenizer tok;
  setUp(() => tok = LyricsTokenizer(fixtureCatalog()));

  List<String> split(String line) => [
    for (final t in tok.tokenize(line))
      if (!t.isGap) t.text,
  ];

  test('words, particles and katakana are split apart', () {
    expect(split('私はコーヒーを飲みました'), ['私', 'は', 'コーヒー', 'を', '飲みました']);
    final t = tok.tokenize('私はコーヒーを飲みました');
    expect(t.first.word!.word.headword, '私');
    expect(t[1].grammar, isNotNull);
    expect(t.last.word!.id, 'w:4');
    expect(t.last.steps, [Inflection.polite, Inflection.past]);
  });

  test('conjugations are traced back to the dictionary form', () {
    LyricToken one(String s) => tok.tokenize(s).single;
    expect(one('食べなかった').word!.id, 'w:3');
    expect(one('食べなかった').steps, [Inflection.negative, Inflection.past]);
    expect(one('飲んで').word!.id, 'w:4');
    expect(one('飲んで').steps, [Inflection.te]);
    expect(one('食べたい').steps, [Inflection.want]);
    expect(one('飲まない').steps, [Inflection.negative]);
  });

  test('unknown words stay whole; spaces and punctuation are gaps', () {
    final t = tok.tokenize('僕と 夜空、ラララ');
    expect(t.map((x) => x.text), ['僕', 'と', ' ', '夜空', '、', 'ラララ']);
    expect(t[3].known, isFalse);
    expect(t[2].isGap, isTrue);
    expect(t[5].known, isFalse);
  });

  test('deinflect lists dictionary forms with their steps', () {
    final d = deinflect('書いた');
    expect(d.any((x) => x.base == '書く' && x.kind == 'v5'), isTrue);
    expect(
      deinflect('来なかった').any((x) => x.base == '来る' && x.kind == 'vk'),
      isTrue,
    );
    expect(deinflect('しました').any((x) => x.base == 'する'), isTrue);
  });
}
