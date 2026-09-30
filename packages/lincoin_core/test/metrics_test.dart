import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 3, 10, 5);
  final s = SrsScheduler(SrsConfig(enableFuzz: false));
  final m = Metrics(s);

  CardState reviewed(
          {required double stability, required int daysAgo, int reps = 3}) =>
      CardState(
        status: CardStatus.review,
        stability: stability,
        difficulty: 5,
        lastReview: now.subtract(Duration(days: daysAgo)),
        due: now,
        reps: reps,
        lastRating: Rating.good,
      );

  test('expected known uses the weakest facet per item', () {
    final strong = reviewed(stability: 100, daysAgo: 1);
    final weak = reviewed(stability: 1, daysAgo: 30);
    final cards = [
      TrackedCard('a#recog', 'a', 'N5', strong),
      TrackedCard('a#recall', 'a', 'N5', weak),
      TrackedCard('b#recog', 'b', 'N5', strong),
      const TrackedCard('c#recog', 'c', 'N5', CardState.initial),
    ];
    final perItem = m.itemRetrievability(cards, now);
    expect(perItem['a'], s.retrievability(weak, now));
    expect(perItem['c'], 0);
    final known = m.expectedKnown(cards, now);
    expect(known, closeTo(perItem['a']! + perItem['b']!, 1e-9));
    expect(m.coverage(cards: cards, totalItemsInLevel: 10, nowUtc: now),
        closeTo(known / 10, 1e-9));
  });

  test('mastered items need every facet mastered', () {
    final mastered = reviewed(stability: 30, daysAgo: 1);
    final cards = [
      TrackedCard('a#recog', 'a', 'N5', mastered),
      TrackedCard('a#recall', 'a', 'N5', reviewed(stability: 5, daysAgo: 1)),
      TrackedCard('b#recog', 'b', 'N5', mastered),
      TrackedCard('b#recall', 'b', 'N5', mastered),
    ];
    expect(m.masteredItems(cards), 1);
  });

  ReviewRecord rec(CardStatus before, Rating r, double? p, {int day = 100}) =>
      ReviewRecord(
          cardId: 'c',
          deck: 'vocab',
          tsUtc: now,
          studyDay: day,
          statusBefore: before,
          rating: r,
          rPredicted: p,
          responseMs: 3000);

  test('true retention counts only review-state answers', () {
    final log = [
      rec(CardStatus.review, Rating.good, 0.9),
      rec(CardStatus.review, Rating.again, 0.9),
      rec(CardStatus.review, Rating.hard, 0.9, day: 50),
      rec(CardStatus.learning, Rating.again, null),
      rec(CardStatus.relearning, Rating.again, 0.5),
    ];
    expect(m.trueRetention(log), closeTo(2 / 3, 1e-9));
    expect(m.trueRetention(log, fromDay: 90), 0.5);
    expect(m.trueRetention([]), isNull);
  });

  test('calibration bins and log loss', () {
    final log = [
      for (var i = 0; i < 9; i++) rec(CardStatus.review, Rating.good, 0.91),
      rec(CardStatus.review, Rating.again, 0.92),
      rec(CardStatus.review, Rating.again, 0.42),
    ];
    final bins = m.calibration(log);
    expect(bins, hasLength(2));
    final high = bins.last;
    expect(high.count, 10);
    expect(high.actual, closeTo(0.9, 1e-9));
    expect(high.meanPredicted, closeTo(0.911, 1e-9));
    final good = m.logLoss(log)!;
    final bad = m.logLoss([
      for (final r in log) rec(r.statusBefore, r.rating, 0.5),
    ])!;
    expect(good, lessThan(bad));
  });

  test('study day rolls over at 04:00 local time', () {
    const bkk = 420;
    final before = DateTime.utc(2025, 3, 10, 20, 59); // 03:59 on the 11th
    final after = DateTime.utc(2025, 3, 10, 21, 1); // 04:01 on the 11th
    final a = studyDayNumber(before, tzOffsetMinutes: bkk);
    final b = studyDayNumber(after, tzOffsetMinutes: bkk);
    expect(b - a, 1);
    expect(studyDayIso(a), '2025-03-10');
    expect(studyDayIso(b), '2025-03-11');
    expect(() => studyDayNumber(DateTime(2025), tzOffsetMinutes: 0),
        throwsArgumentError);
  });
}
