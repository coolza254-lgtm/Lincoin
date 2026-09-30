import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  group('Grader', () {
    const g = Grader();
    Rating grade(AnswerEvent e) => g.grade(e, medianMs: 5000);

    test('wrong, gave up or guessed is Again', () {
      expect(grade(const AnswerEvent(isCorrect: false, responseMs: 3000)),
          Rating.again);
      expect(
          grade(const AnswerEvent(
              isCorrect: true, responseMs: 3000, gaveUp: true)),
          Rating.again);
      expect(
          grade(const AnswerEvent(
              isCorrect: true, responseMs: 3000, markedGuess: true)),
          Rating.again);
    });

    test('speed relative to personal median decides Hard/Good/Easy', () {
      expect(grade(const AnswerEvent(isCorrect: true, responseMs: 11000)),
          Rating.hard);
      expect(grade(const AnswerEvent(isCorrect: true, responseMs: 5000)),
          Rating.good);
      expect(grade(const AnswerEvent(isCorrect: true, responseMs: 2500)),
          Rating.easy);
    });

    test('a hint caps the rating at Hard', () {
      expect(
          grade(const AnswerEvent(
              isCorrect: true, responseMs: 1000, usedHint: true)),
          Rating.hard);
    });

    test('very long pauses are capped, falls back to default median', () {
      expect(g.grade(const AnswerEvent(isCorrect: true, responseMs: 3600000)),
          Rating.hard);
      expect(g.grade(const AnswerEvent(isCorrect: true, responseMs: 6000)),
          Rating.good);
    });
  });

  group('ResponseTimeTracker', () {
    test('median needs enough samples and ignores assisted answers', () {
      final t = ResponseTimeTracker(window: 5, minSamples: 3);
      t.add('recog', const AnswerEvent(isCorrect: true, responseMs: 1000));
      t.add('recog',
          const AnswerEvent(isCorrect: true, responseMs: 9000, usedHint: true));
      t.add('recog', const AnswerEvent(isCorrect: false, responseMs: 9000));
      expect(t.median('recog'), isNull);
      t.add('recog', const AnswerEvent(isCorrect: true, responseMs: 3000));
      t.add('recog', const AnswerEvent(isCorrect: true, responseMs: 2000));
      expect(t.median('recog'), 2000);
      for (var i = 0; i < 5; i++) {
        t.add('recog', const AnswerEvent(isCorrect: true, responseMs: 8000));
      }
      expect(t.median('recog'), 8000);
      expect(t.median('recall'), isNull);
    });
  });

  group('kana', () {
    test('basic and yōon', () {
      expect(romajiToHiragana('toshokan'), 'としょかん');
      expect(romajiToHiragana('kyou'), 'きょう');
      expect(romajiToHiragana('ryokou'), 'りょこう');
      expect(romajiToHiragana('tabemasu'), 'たべます');
    });

    test('Hepburn, Kunrei and IME spellings agree', () {
      for (final pair in [
        ['shinbun', 'sinbun'],
        ['chizu', 'tizu'],
        ['tsukue', 'tukue'],
        ['fuji', 'huzi'],
        ['jisho', 'zisyo'],
        ['cha', 'tya'],
      ]) {
        expect(romajiToHiragana(pair[0]), romajiToHiragana(pair[1]),
            reason: '$pair');
      }
    });

    test('ん handling', () {
      expect(romajiToHiragana('konnichiha'), 'こんにちは');
      expect(romajiToHiragana('sannen'), 'さんねん');
      expect(romajiToHiragana("kin'en"), 'きんえん');
      expect(romajiToHiragana('kinen'), 'きねん');
      expect(romajiToHiragana('hon'), 'ほん');
      expect(romajiToHiragana('honn'), 'ほん');
      expect(romajiToHiragana('shinpai'), 'しんぱい');
      expect(romajiToHiragana("hon'ya"), 'ほんや');
    });

    test('small tsu and long vowels', () {
      expect(romajiToHiragana('kitte'), 'きって');
      expect(romajiToHiragana('zasshi'), 'ざっし');
      expect(romajiToHiragana('matcha'), 'まっちゃ');
      expect(romajiToHiragana('macchа'.replaceAll('а', 'a')), 'まっちゃ');
      expect(romajiToHiragana('ko-hi-'), 'こーひー');
    });

    test('readings compare across romaji, hiragana and katakana', () {
      expect(readingMatches('ko-hi-', ['コーヒー']), isTrue);
      expect(readingMatches('としょかん', ['としょかん']), isTrue);
      expect(readingMatches(' Toshokan ', ['としょかん']), isTrue);
      expect(readingMatches('toshoka', ['としょかん']), isFalse);
      expect(readingMatches('', ['']), isFalse);
      expect(readingMatches('kyou', ['きょう', 'こんにち']), isTrue);
    });
  });
}
