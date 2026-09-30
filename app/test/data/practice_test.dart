import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/features/practice/drill_controller.dart';
import 'package:lincoin/services/challenge_service.dart';
import 'package:lincoin/services/practice_service.dart';
import 'package:lincoin/services/study_service.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../support/fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserDb db;
  late Catalog catalog;
  var now = DateTime.utc(2026, 10, 1, 3);

  StudyService study() => StudyService(
    db: db,
    catalog: catalog,
    settings: const AppSettings(),
    clock: Clock(() => now, () => 420),
  );

  /// Studies every fixture item once so practice has a pool.
  void learnAll() {
    final s = study();
    for (final item in catalog.path) {
      final q = s.question(cardIdFor(item.id, item.facets.first));
      s.introduce(q);
      s.answer(q, const AnswerEvent(isCorrect: true, responseMs: 5000));
    }
  }

  void seedCoins(int n) => LedgerRepo(db).insertAll([
    LedgerEntry(
      id: 'seed',
      tsUtc: now,
      delta: n,
      reason: LedgerReason.review,
      idempotencyKey: 'seed',
      studyDay: 0,
    ),
  ]);

  setUp(() {
    db = UserDb.memory();
    catalog = fixtureCatalog();
    now = DateTime.utc(2026, 10, 1, 3);
  });

  test('pool contains studied items only; questions are well formed', () {
    final p = PracticeService(study());
    expect(p.pool(), isEmpty);
    learnAll();
    final pool = p.pool();
    expect(pool, hasLength(catalog.path.length));
    final rnd = math.Random(1);
    final forms = <QuestionForm>{};
    for (var i = 0; i < 60; i++) {
      final q = p.question(pool[i % pool.length], rnd);
      forms.add(q.form);
      if (q.choices != null) {
        expect(q.choices!.options.toSet().length, q.choices!.options.length);
      }
    }
    expect(forms, containsAll(QuestionForm.values));
    final choiceOnly = {
      for (var i = 0; i < 30; i++)
        p.question(pool[i % pool.length], rnd, choiceOnly: true).isTyped,
    };
    expect(choiceOnly, {false});
  });

  test('practice answers never touch the FSRS state', () {
    learnAll();
    final before = StudyRepo(db).cards();
    final p = PracticeService(study());
    final pool = p.pool();
    for (var i = 0; i < 10; i++) {
      p.record(
        q: p.question(pool[i % pool.length], math.Random(i)),
        correct: true,
        responseMs: 2000,
        mode: 'practice',
        sessionId: 's',
      );
    }
    final after = StudyRepo(db).cards();
    for (final id in before.keys) {
      expect(after[id]!.state, before[id]!.state);
    }
    expect(StudyRepo(db).reviewRecords(), hasLength(catalog.path.length));
  });

  test('practice pays with per-card cap; challenge answers pay nothing', () {
    learnAll();
    final p = PracticeService(study());
    final item = p.pool().first;
    final q = p.question(item, math.Random(3), choiceOnly: true);
    var paid = 0;
    for (var i = 0; i < 5; i++) {
      paid += p
          .record(
            q: q,
            correct: true,
            responseMs: 2000,
            mode: 'practice',
            sessionId: 's',
          )
          .coinTotal;
    }
    expect(paid, 3); // 1 per answer, max 3 payouts per card per day
    final c = p.record(
      q: q,
      correct: true,
      responseMs: 2000,
      mode: 'challenge',
      sessionId: 's',
    );
    expect(c.coinTotal, 0);
    expect(p.todayPractice().$1, 3);
  });

  group('challenges', () {
    test('stake, win payout, loss, and one active at a time', () {
      learnAll();
      seedCoins(1000);
      final ch = ChallengeService(study());
      final o = ch.offer(ChallengeType.speed, 'normal', 1000);
      expect(o.threshold, ChallengeType.speed.fallback['normal']);
      expect(o.maxStake, 300); // 30 % of the balance
      expect(o.calibrating, isTrue);
      final c = ch.start(o, 100);
      expect(LedgerRepo(db).balance(), 900);
      expect(() => ch.start(o, 100), throwsStateError);
      final won = ch.finish(c.id, o.threshold);
      expect(won.result, 'won');
      expect(LedgerRepo(db).balance(), 1100); // 900 + 100 × 2.0
      // Finishing again changes nothing.
      ch.finish(c.id, 0);
      expect(LedgerRepo(db).balance(), 1100);
      final c2 = ch.start(ch.offer(ChallengeType.speed, 'normal', 1100), 50);
      expect(ch.finish(c2.id, 1).result, 'lost');
      expect(LedgerRepo(db).balance(), 1050);
    });

    test('thresholds adapt to recent scores after 5 rounds', () {
      learnAll();
      seedCoins(100000);
      final ch = ChallengeService(study());
      for (final s in [20, 22, 24, 26, 28, 30]) {
        final c = ch.start(ch.offer(ChallengeType.speed, 'easy', 100000), 20);
        ch.finish(c.id, s);
      }
      final easy = ch.offer(ChallengeType.speed, 'easy', 100000);
      final brutal = ch.offer(ChallengeType.speed, 'brutal', 100000);
      expect(easy.calibrating, isFalse);
      expect(easy.threshold, inInclusiveRange(20, 25));
      expect(brutal.threshold, greaterThan(easy.threshold));
    });

    test('abandoned rounds are forfeited at start-up', () {
      learnAll();
      seedCoins(1000);
      final ch = ChallengeService(study());
      ch.start(ch.offer(ChallengeType.streak, 'easy', 1000), 20);
      expect(ch.forfeitAbandoned(), 1);
      expect(ch.active(), isEmpty);
      expect(LedgerRepo(db).balance(), 980);
    });

    test(
      'weekly: won when enough days are cleared, lost when out of reach',
      () {
        learnAll();
        seedCoins(1000);
        final s = study();
        final ch = ChallengeService(s);
        final c = ch.start(ch.offer(ChallengeType.weekly, 'easy', 1000), 100);
        final day = s.studyDay();
        // Clear 4 days (daily-clear entries are what counts).
        for (var d = 0; d < 4; d++) {
          LedgerRepo(db).insertAll([
            s.rewards.dailyClear(
              deck: vocabDeck,
              nowUtc: now,
              studyDay: day + d,
            ),
          ]);
        }
        final settled = ch.settleWeekly();
        expect(settled.single.result, 'won');
        expect(settled.single.id, c.id);

        now = now.add(const Duration(days: 10));
        final ch2 = ChallengeService(study());
        final c2 = ch2.start(
          ch2.offer(ChallengeType.weekly, 'brutal', 2000),
          100,
        );
        expect(ch2.settleWeekly(), isEmpty);
        now = now.add(const Duration(days: 2)); // missed days → 7/7 impossible
        expect(ChallengeService(study()).settleWeekly().single.id, c2.id);
      },
    );

    test(
      'drill: a streak round ends at the first mistake and settles',
      () async {
        learnAll();
        seedCoins(1000);
        final s = study();
        final ch = ChallengeService(s);
        final c = ch.start(ch.offer(ChallengeType.streak, 'easy', 1000), 20);
        final drill = DrillController(
          practice: PracticeService(s),
          challenges: ch,
          config: DrillConfig.challenge(c),
          onDataChanged: () {},
          random: math.Random(7),
        );
        for (var i = 0; i < 3; i++) {
          drill.choose(drill.question!.choices!.correctIndex);
          await Future<void>.delayed(const Duration(milliseconds: 950));
        }
        final wrong =
            (drill.question!.choices!.correctIndex + 1) %
            drill.question!.choices!.options.length;
        drill.choose(wrong);
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        expect(drill.phase, DrillPhase.done);
        expect(drill.score, 3);
        expect(drill.result!.result, 'lost'); // easy fallback is 5
        drill.dispose();
      },
    );
  });
}
