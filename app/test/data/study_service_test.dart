import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/services/study_service.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../support/fixture.dart';

void main() {
  late UserDb db;
  late Catalog catalog;
  var now = DateTime.utc(2026, 10, 1, 3); // 10:00 Bangkok
  const tz = 420;

  StudyService service([AppSettings s = const AppSettings()]) => StudyService(
    db: db,
    catalog: catalog,
    settings: s,
    clock: Clock(() => now, () => tz),
  );

  setUp(() {
    db = UserDb.memory();
    catalog = fixtureCatalog();
    now = DateTime.utc(2026, 10, 1, 3);
  });

  test('path: kana first, then words; recall only after recog', () {
    final p = service().plan();
    final ids = p.queue.newCards.map((c) => c.cardId).toList();
    expect(ids.take(3), ['k:hira.a#kana', 'k:hira.i#kana', 'k:hira.ka#kana']);
    expect(ids.where((i) => i.endsWith('#recall')), isEmpty);
    expect(ids, hasLength(10));
  });

  test('without kana the path starts at N5', () {
    final p = service(const AppSettings(includeKana: false)).plan();
    expect(p.queue.newCards.first.cardId, 'w:1#recog');
  });

  test('new-card limit counts introductions today', () {
    final s = service(const AppSettings(vocabNewPerDay: 2));
    final q = s.question(s.plan().queue.newCards.first.cardId);
    expect(q.needsIntro, isTrue);
    s.introduce(q);
    expect(s.plan().newCount, 1);
  });

  test('answering records log, state and Lincoin atomically', () {
    final s = service(const AppSettings(includeKana: false));
    final q = s.question('w:1#recog');
    expect(q.choices!.options[q.choices!.correctIndex], 'ฤดูใบไม้ร่วง');
    s.introduce(q);
    final r = s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    expect(r.rating, Rating.good);
    expect(r.outcome.after.status, CardStatus.learning);
    final stored = StudyRepo(db).card('w:1#recog')!;
    expect(stored.state, r.outcome.after);
    expect(StudyRepo(db).reviewRecords(), hasLength(1));
    // New card in learning earns nothing yet.
    expect(LedgerRepo(db).balance(), 0);
  });

  test('graduating pays "learned" once; recall unlocks next day', () {
    final s = service(const AppSettings(includeKana: false));
    final q = s.question('w:1#recog');
    s.introduce(q);
    for (var i = 0; i < 2; i++) {
      s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
      now = now.add(const Duration(minutes: 15));
    }
    final card = StudyRepo(db).card('w:1#recog')!;
    expect(card.state.status, CardStatus.review);
    expect(LedgerRepo(db).balance(), 5);
    // Sibling recall card is buried today, offered as new tomorrow.
    expect(
      s.plan().queue.newCards.map((c) => c.cardId),
      isNot(contains('w:1#recall')),
    );
    now = now.add(const Duration(days: 1));
    expect(
      service(const AppSettings(includeKana: false))
          .plan()
          .queue
          .newCards
          .map((c) => c.cardId),
      contains('w:1#recall'),
    );
  });

  test('typed answers: romaji, katakana long vowel, synonym', () {
    final s = service();
    Question recall(String id) => Question(
      cardId: '$id#recall',
      item: catalog.byId[id]!,
      facet: Facet.recall,
      type: 'recall.type',
    );
    expect(s.checkTyped(recall('w:3'), 'taberu'), AnswerCheck.correct);
    expect(s.checkTyped(recall('w:3'), 'たべる'), AnswerCheck.correct);
    expect(s.checkTyped(recall('w:3'), 'nomu'), AnswerCheck.wrong);
    expect(s.checkTyped(recall('w:7'), 'koohii'), AnswerCheck.correct);
    expect(s.checkTyped(recall('w:5'), 'boku'), AnswerCheck.synonym);
    final kana = s.question('k:hira.ka#kana');
    expect(s.checkTyped(kana, 'KA'), AnswerCheck.correct);
    expect(s.checkTyped(kana, 'ga'), AnswerCheck.wrong);
  });

  test('daily clear bonus once per day, only when nothing is due', () {
    final s = service(const AppSettings(includeKana: false, vocabNewPerDay: 1));
    final q = s.question('w:1#recog');
    s.introduce(q);
    s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    // Card is in a learning step (due soon) → not cleared.
    expect(s.finishSession(answeredAny: true).total, 0);
    now = now.add(const Duration(minutes: 30));
    s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    now = now.add(const Duration(minutes: 30));
    s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    final b = s.finishSession(answeredAny: true);
    expect(b.entries.map((e) => e.reason), contains(LedgerReason.dailyClear));
    expect(s.finishSession(answeredAny: true).total, 0);
  });

  test('session order spreads new cards among reviews', () {
    final s = service();
    final order = s.sessionOrder(s.plan());
    expect(order.toSet(), hasLength(order.length));
  });

  test('deprecations move or suspend cards', () {
    final s = service(const AppSettings(includeKana: false));
    for (final id in ['w:1#recog', 'w:2#recog']) {
      final q = s.question(id);
      s.introduce(q);
      s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    }
    final n = StudyRepo(db).applyDeprecations({'w:1': 'w:100', 'w:2': null});
    expect(n, 2);
    final cards = StudyRepo(db).cards();
    expect(cards.containsKey('w:100#recog'), isTrue);
    expect(cards['w:2#recog']!.suspended, isTrue);
  });

  group('grammar deck', () {
    StudyService grammar() => StudyService(
      db: db,
      catalog: catalog,
      settings: const AppSettings(grammarNewPerDay: 5),
      clock: Clock(() => now, () => 420),
      deck: grammarDeck,
    );

    test('only points with translated examples; separate deck and limits', () {
      expect(catalog.itemsPerLevel(grammarDeck), {'n5': 2});
      final p = grammar().plan();
      expect(p.queue.newCards.map((c) => c.cardId), [
        'g:n5.001#cloze',
        'g:n5.002#cloze',
      ]);
      // Vocab plan is unaffected.
      expect(
        service().plan().queue.newCards.map((c) => c.cardId),
        everyElement(isNot(startsWith('g:'))),
      );
    });

    test('cloze uses a translated example and rotates by repetition', () {
      final g = grammar();
      final q = g.question('g:n5.001#cloze');
      expect(q.form, QuestionForm.cloze);
      expect(q.needsIntro, isTrue);
      expect(q.choices!.options[q.choices!.correctIndex], 'を');
      expect(q.choices!.options.toSet(), {'を', 'に', 'で', 'の'});
      expect(q.example!.parts, ('コーヒー', 'を', '飲みます。'));
      g.introduce(q);
      g.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
      final q2 = g.question('g:n5.001#cloze');
      expect(q2.example!.sentence.id, 'ex:3');
      final stored = StudyRepo(db).card('g:n5.001#cloze')!;
      expect(stored.deck, grammarDeck);
      expect(StudyRepo(db).reviewRecords(deck: grammarDeck), hasLength(1));
    });
  });
}
