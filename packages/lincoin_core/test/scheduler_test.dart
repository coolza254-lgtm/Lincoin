import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2022, 11, 29, 12, 30);

  group('SrsScheduler', () {
    test('matches the FSRS reference interval sequence (fuzz off)', () {
      // Same ratings and expected intervals as the upstream fsrs test suite.
      final s = SrsScheduler(SrsConfig(enableFuzz: false));
      const ratings = [
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.again,
        Rating.again,
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.good,
        Rating.good,
      ];
      var state = CardState.initial;
      var now = t0;
      final ivls = <int>[];
      for (final r in ratings) {
        state =
            s.review(cardId: 'c', state: state, rating: r, nowUtc: now).after;
        ivls.add(state.due!.difference(state.lastReview!).inDays);
        now = state.due!;
      }
      expect(ivls, [0, 4, 14, 45, 135, 372, 0, 0, 2, 5, 10, 20, 40]);
    });

    test('new card goes through learning steps then graduates', () {
      final s = SrsScheduler(SrsConfig(enableFuzz: false));
      var o = s.review(
          cardId: 'c',
          state: CardState.initial,
          rating: Rating.good,
          nowUtc: t0);
      expect(o.after.status, CardStatus.learning);
      expect(o.after.due, t0.add(const Duration(minutes: 10)));
      expect(o.graduated, isFalse);
      expect(o.retrievabilityBefore, isNull);

      o = s.review(
          cardId: 'c',
          state: o.after,
          rating: Rating.good,
          nowUtc: o.after.due!);
      expect(o.after.status, CardStatus.review);
      expect(o.graduated, isTrue);
      expect(o.after.reps, 2);
    });

    test('forgetting a review card counts a lapse and enters relearning', () {
      final s = SrsScheduler(SrsConfig(enableFuzz: false));
      var st = s
          .review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.easy,
              nowUtc: t0)
          .after;
      expect(st.status, CardStatus.review);
      final o = s.review(
          cardId: 'c', state: st, rating: Rating.again, nowUtc: st.due!);
      expect(o.lapsed, isTrue);
      expect(o.after.lapses, 1);
      expect(o.after.status, CardStatus.relearning);
      expect(o.retrievabilityBefore, inInclusiveRange(0.0, 1.0));
      st = o.after;
      // Failing again while relearning is not another lapse.
      st = s
          .review(cardId: 'c', state: st, rating: Rating.again, nowUtc: st.due!)
          .after;
      expect(st.lapses, 1);
    });

    test('replay reproduces the incremental state exactly (fuzz on)', () {
      final s = SrsScheduler(SrsConfig());
      const pattern = [
        Rating.good,
        Rating.good,
        Rating.hard,
        Rating.good,
        Rating.again,
        Rating.good,
        Rating.good,
        Rating.easy,
        Rating.good
      ];
      var st = CardState.initial;
      var now = t0;
      final log = <ReviewInput>[];
      for (final r in pattern) {
        log.add(ReviewInput(r, now));
        st = s
            .review(cardId: 'w:1#recog', state: st, rating: r, nowUtc: now)
            .after;
        now = st.due!.add(const Duration(hours: 3));
      }
      expect(s.replay('w:1#recog', log), st);
      expect(SrsScheduler(SrsConfig()).replay('w:1#recog', log), st);
    });

    test('fuzz stays within range and is deterministic', () {
      final s = SrsScheduler(SrsConfig());
      for (final ivl in [1, 2, 3, 5, 10, 30, 100, 1000]) {
        final seen = <int>{};
        for (var k = 0; k < 200; k++) {
          final f = s.fuzzIntervalDays(ivl, 'card$k');
          expect(f, s.fuzzIntervalDays(ivl, 'card$k'));
          if (ivl < 3) {
            expect(f, ivl);
          } else {
            expect(f, greaterThanOrEqualTo(2));
            expect((f - ivl).abs(), lessThanOrEqualTo((ivl * 0.1).ceil() + 2));
          }
          seen.add(f);
        }
        if (ivl >= 10) expect(seen.length, greaterThan(1));
      }
    });

    test('rejects non-UTC and time travel', () {
      final s = SrsScheduler(SrsConfig());
      expect(
          () => s.review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.good,
              nowUtc: DateTime(2024)),
          throwsArgumentError);
      final st = s
          .review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.good,
              nowUtc: t0)
          .after;
      expect(
          () => s.review(
              cardId: 'c',
              state: st,
              rating: Rating.good,
              nowUtc: t0.subtract(const Duration(days: 1))),
          throwsArgumentError);
    });

    test('retrievability is 0 for new cards and decays over time', () {
      final s = SrsScheduler(SrsConfig(enableFuzz: false));
      expect(s.retrievability(CardState.initial, t0), 0);
      final st = s
          .review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.easy,
              nowUtc: t0)
          .after;
      final r1 = s.retrievability(st, t0.add(const Duration(days: 1)));
      final r30 = s.retrievability(st, t0.add(const Duration(days: 30)));
      expect(r1, greaterThan(r30));
      // At the scheduled due date recall is close to desired retention.
      expect(s.retrievability(st, st.due!), closeTo(0.9, 0.03));
    });

    test('desired retention is bounded', () {
      expect(() => SrsConfig(desiredRetention: 0.99), throwsArgumentError);
      expect(() => SrsConfig(desiredRetention: 0.7), throwsArgumentError);
      final strict =
          SrsScheduler(SrsConfig(desiredRetention: 0.95, enableFuzz: false));
      final loose =
          SrsScheduler(SrsConfig(desiredRetention: 0.85, enableFuzz: false));
      CardState grad(SrsScheduler s) => s
          .review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.easy,
              nowUtc: t0)
          .after;
      expect(grad(strict).due!.isBefore(grad(loose).due!), isTrue);
    });

    test('CardState JSON round trip', () {
      final s = SrsScheduler(SrsConfig());
      final st = s
          .review(
              cardId: 'c',
              state: CardState.initial,
              rating: Rating.good,
              nowUtc: t0)
          .after;
      expect(CardState.fromJson(st.toJson()), st);
      expect(CardState.fromJson(CardState.initial.toJson()), CardState.initial);
    });

    test('leech and mastery rules', () {
      final s = SrsScheduler(SrsConfig(enableFuzz: false));
      expect(s.isLeech(const CardState(status: CardStatus.review, lapses: 8)),
          isTrue);
      expect(s.isLeech(const CardState(status: CardStatus.review, lapses: 7)),
          isFalse);

      const rule = MasteryRule();
      var st = CardState.initial;
      var now = t0;
      var reps = 0;
      while (!rule.isMastered(st)) {
        st = s
            .review(cardId: 'c', state: st, rating: Rating.good, nowUtc: now)
            .after;
        now = st.due!;
        expect(++reps, lessThan(20));
      }
      expect(st.stability!, greaterThanOrEqualTo(21));
      final forgot = s
          .review(cardId: 'c', state: st, rating: Rating.again, nowUtc: now)
          .after;
      expect(rule.isMastered(forgot), isFalse);
    });
  });
}
