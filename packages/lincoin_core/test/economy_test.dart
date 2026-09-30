import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 3, 10, 5);
  const day = 20157;
  var n = 0;
  String id() => 'id${n++}';

  group('RewardEngine: reviews', () {
    final engine = RewardEngine(newId: id);

    ReviewRewardInput input({
      String log = 'L1',
      CardStatus before = CardStatus.review,
      Rating rating = Rating.good,
      int ms = 3000,
      bool graduated = false,
      bool firstMastered = false,
    }) =>
        ReviewRewardInput(
          reviewLogId: log,
          cardId: 'w:1#recog',
          deck: 'vocab',
          statusBefore: before,
          rating: rating,
          responseMs: ms,
          graduated: graduated,
          firstMastered: firstMastered,
        );

    List<LedgerEntry> reward(ReviewRewardInput e,
            [DailyTotals t = const DailyTotals()]) =>
        engine.forReview(e, nowUtc: now, studyDay: day, today: t);

    test('correct due review pays 2, relearn pays 3, wrong pays 0', () {
      expect(reward(input()).single.delta, 2);
      expect(reward(input(before: CardStatus.relearning)).single.delta, 3);
      expect(reward(input(rating: Rating.again)), isEmpty);
    });

    test('learning-step answers pay nothing until graduation (+5)', () {
      expect(reward(input(before: CardStatus.learning)), isEmpty);
      final e = reward(input(before: CardStatus.learning, graduated: true));
      expect(e.single.delta, 5);
      expect(e.single.idempotencyKey, 'learned:w:1#recog');
    });

    test('first mastery pays once', () {
      final ledger = Ledger();
      for (final e in reward(input(firstMastered: true))) {
        ledger.add(e);
      }
      for (final e in reward(input(log: 'L2', firstMastered: true))) {
        ledger.add(e);
      }
      expect(ledger.balance, 2 + 10 + 2);
    });

    test('inhumanly fast answers earn nothing', () {
      expect(reward(input(ms: 250)), isEmpty);
    });

    test('daily review cap', () {
      expect(
          reward(input(), const DailyTotals(reviewCoins: 299)).single.delta, 1);
      expect(reward(input(), const DailyTotals(reviewCoins: 300)), isEmpty);
    });

    test('coverage milestones pay once each', () {
      final ledger = Ledger();
      for (final c in [0.3, 0.3, 0.55, 1.0]) {
        for (final e in engine.forCoverage(
            deck: 'vocab',
            level: 'N5',
            coverage: c,
            nowUtc: now,
            studyDay: day)) {
          ledger.add(e);
        }
      }
      expect(ledger.balance, 100 + 250 + 500 + 1000);
    });

    test('daily clear once per deck per day', () {
      final ledger = Ledger();
      ledger.add(engine.dailyClear(deck: 'vocab', nowUtc: now, studyDay: day));
      ledger.add(engine.dailyClear(deck: 'vocab', nowUtc: now, studyDay: day));
      ledger
          .add(engine.dailyClear(deck: 'grammar', nowUtc: now, studyDay: day));
      expect(ledger.balance, 40);
    });
  });

  group('RewardEngine: practice', () {
    final engine = RewardEngine(newId: id);

    int playPractice(int answers, {bool weak = false}) {
      final ledger = Ledger();
      for (var i = 0; i < answers; i++) {
        final e = engine.forPractice(
          PracticeRewardInput(
              practiceLogId: 'p$i',
              cardId: 'c$i',
              isCorrect: true,
              responseMs: 2000,
              isWeakItem: weak),
          nowUtc: now,
          studyDay: day,
          today: ledger.totalsFor(day),
        );
        if (e != null) ledger.add(e);
      }
      return ledger.balance;
    }

    test('diminishing returns: 100 full, next 100 half, then 10%', () {
      expect(playPractice(100), 100);
      expect(playPractice(200), 150);
      expect(playPractice(400), 170);
    });

    test('weak items pay 1.5×', () {
      expect(playPractice(10, weak: true), 15);
    });

    test('same card pays at most 3 times a day', () {
      final ledger = Ledger();
      for (var i = 0; i < 6; i++) {
        final e = engine.forPractice(
          PracticeRewardInput(
              practiceLogId: 'q$i',
              cardId: 'same',
              isCorrect: true,
              responseMs: 2000),
          nowUtc: now,
          studyDay: day,
          today: ledger.totalsFor(day),
        );
        if (e != null) ledger.add(e);
      }
      expect(ledger.balance, 3);
    });

    test('combo bonus every 5 in a row', () {
      final e = engine.forPractice(
        const PracticeRewardInput(
            practiceLogId: 'x',
            cardId: 'c',
            isCorrect: true,
            responseMs: 2000,
            comboCount: 5),
        nowUtc: now,
        studyDay: day,
        today: const DailyTotals(),
      );
      expect(e!.delta, 2);
    });
  });

  group('Ledger', () {
    LedgerEntry e(String key, int delta) => LedgerEntry(
        id: key,
        tsUtc: now,
        delta: delta,
        reason: 'test',
        idempotencyKey: key,
        studyDay: day);

    test('rejects duplicates and overdrafts; balance is the sum', () {
      final l = Ledger();
      expect(l.add(e('a', 50)), isTrue);
      expect(l.add(e('a', 50)), isFalse);
      expect(l.add(e('b', -60)), isFalse);
      expect(l.add(e('c', -50)), isTrue);
      expect(l.balance, 0);
    });

    test('JSON round trip', () {
      final x = e('k', 7);
      final y = LedgerEntry.fromJson(x.toJson());
      expect([y.id, y.delta, y.idempotencyKey, y.studyDay, y.tsUtc],
          [x.id, x.delta, x.idempotencyKey, x.studyDay, x.tsUtc]);
    });
  });

  group('Challenge', () {
    const rules = ChallengeRules();

    test('stake limits', () {
      expect(rules.maxStakeFor(1240), 372);
      expect(rules.maxStakeFor(10000), 1000);
      expect(rules.canStart(balance: 1240, stake: 200, activeCount: 0), isTrue);
      expect(
          rules.canStart(balance: 1240, stake: 400, activeCount: 0), isFalse);
      expect(rules.canStart(balance: 1240, stake: 10, activeCount: 0), isFalse);
      expect(
          rules.canStart(balance: 1240, stake: 200, activeCount: 1), isFalse);
      expect(rules.canStart(balance: 50, stake: 20, activeCount: 0), isFalse);
    });

    test('every tier has slightly negative expected value', () {
      for (final t in rules.config.tiers) {
        expect(t.expectedReturn, lessThan(1.0), reason: t.id);
        expect(t.expectedReturn, greaterThan(0.85), reason: t.id);
      }
    });

    test('threshold follows recent performance and tier', () {
      final scores = [for (var i = 1; i <= 20; i++) i];
      final easy =
          rules.threshold(recentScores: scores, tierId: 'easy', fallback: 15);
      final normal =
          rules.threshold(recentScores: scores, tierId: 'normal', fallback: 15);
      final brutal =
          rules.threshold(recentScores: scores, tierId: 'brutal', fallback: 15);
      expect(easy < normal && normal < brutal, isTrue);
      // Empirical win rate against own history is close to the target.
      final wins = scores.where((s) => s >= normal).length / scores.length;
      expect(wins, closeTo(0.48, 0.1));
      expect(
          rules.threshold(recentScores: [1, 2], tierId: 'normal', fallback: 15),
          15);
    });

    test('stake and win flow through the ledger', () {
      final l = Ledger([
        LedgerEntry(
            id: 'seed',
            tsUtc: now,
            delta: 1000,
            reason: 'test',
            idempotencyKey: 'seed',
            studyDay: day)
      ]);
      expect(
          l.add(rules.stakeEntry(
              id: 's',
              challengeId: 'ch1',
              stake: 200,
              nowUtc: now,
              studyDay: day)),
          isTrue);
      expect(l.balance, 800);
      l.add(rules.winEntry(
          id: 'w',
          challengeId: 'ch1',
          stake: 200,
          tierId: 'normal',
          nowUtc: now,
          studyDay: day));
      l.add(rules.winEntry(
          id: 'w2',
          challengeId: 'ch1',
          stake: 200,
          tierId: 'normal',
          nowUtc: now,
          studyDay: day));
      expect(l.balance, 1200);
    });
  });

  test('EngineConfig JSON round trip and forward-compatible defaults', () {
    final cfg = EngineConfig(vocab: SrsConfig(desiredRetention: 0.92));
    final back = EngineConfig.fromJson(cfg.toJson());
    expect(back.toJson(), cfg.toJson());
    expect(back.vocab.desiredRetention, 0.92);
    final partial = EngineConfig.fromJson({'schemaVersion': 1});
    expect(partial.toJson(), EngineConfig().toJson());
    expect(() => EngineConfig.fromJson({'schemaVersion': 99}),
        throwsFormatException);
  });
}
