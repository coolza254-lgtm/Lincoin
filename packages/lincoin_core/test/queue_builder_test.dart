import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 3, 10, 5); // 12:00 in Bangkok (+07:00)
  const tz = 420;
  final s = SrsScheduler(SrsConfig(enableFuzz: false));

  CardState reviewCard(
          {required int stability, required int daysAgo, int dueInDays = 0}) =>
      CardState(
        status: CardStatus.review,
        stability: stability.toDouble(),
        difficulty: 5,
        lastReview: now.subtract(Duration(days: daysAgo)),
        due: now.add(Duration(days: dueInDays)),
        reps: 3,
      );

  QueueCard qc(String id, String item, CardState st,
          {int order = 0, bool suspended = false}) =>
      QueueCard(
          cardId: id,
          itemId: item,
          state: st,
          newOrder: order,
          suspended: suspended);

  QueueBuilder builder([QueueSettings settings = const QueueSettings()]) =>
      QueueBuilder(s, settings);

  test('due reviews come lowest retrievability first; future cards excluded',
      () {
    final q = builder().build(cards: [
      qc('a#recog', 'a', reviewCard(stability: 30, daysAgo: 5)),
      qc('b#recog', 'b', reviewCard(stability: 2, daysAgo: 5)),
      qc('c#recog', 'c', reviewCard(stability: 10, daysAgo: 5)),
      qc('d#recog', 'd', reviewCard(stability: 10, daysAgo: 1, dueInDays: 3)),
    ], nowUtc: now, tzOffsetMinutes: tz);
    expect(q.reviews.map((c) => c.cardId), ['b#recog', 'c#recog', 'a#recog']);
  });

  test('a review due later today (before the 04:00 rollover) is included', () {
    final st = reviewCard(stability: 5, daysAgo: 4)
        .copyWithDue(now.add(const Duration(hours: 15)));
    final q = builder().build(
        cards: [qc('a#recog', 'a', st)], nowUtc: now, tzOffsetMinutes: tz);
    expect(q.reviews, hasLength(1));
  });

  test('sibling facets of the same item are buried until tomorrow', () {
    final q = builder().build(
        cards: [
          qc('a#recog', 'a', reviewCard(stability: 3, daysAgo: 5)),
          qc('a#recall', 'a', reviewCard(stability: 9, daysAgo: 5)),
          qc('b#recall', 'b', CardState.initial),
        ],
        nowUtc: now,
        tzOffsetMinutes: tz,
        itemsSeenToday: {'b'});
    expect(q.reviews.map((c) => c.cardId), ['a#recog']);
    expect(q.buriedSiblings.map((c) => c.cardId),
        containsAll(['a#recall', 'b#recall']));
    expect(q.newCards, isEmpty);
  });

  test('learning steps come first and claim their item', () {
    final learning = s
        .review(
            cardId: 'x#recog',
            state: CardState.initial,
            rating: Rating.good,
            nowUtc: now.subtract(const Duration(minutes: 15)))
        .after;
    final q = builder().build(cards: [
      qc('x#recog', 'x', learning),
      qc('x#recall', 'x', reviewCard(stability: 3, daysAgo: 5)),
    ], nowUtc: now, tzOffsetMinutes: tz);
    expect(q.steps.map((c) => c.cardId), ['x#recog']);
    expect(q.reviews, isEmpty);
  });

  test('new cards respect order and remaining daily limit', () {
    final cards = [
      for (var i = 0; i < 20; i++)
        qc('n$i#recog', 'n$i', CardState.initial, order: 20 - i)
    ];
    final q = builder(const QueueSettings(newPerDay: 10)).build(
        cards: cards, nowUtc: now, tzOffsetMinutes: tz, newIntroducedToday: 4);
    expect(q.newCards, hasLength(6));
    expect(q.newCards.first.cardId, 'n19#recog');
  });

  test('backlog pauses new cards', () {
    final cards = [
      for (var i = 0; i < 5; i++)
        qc('r$i', 'r$i', reviewCard(stability: 5, daysAgo: 6)),
      qc('new', 'new', CardState.initial),
    ];
    final q = builder(const QueueSettings(backlogThreshold: 4))
        .build(cards: cards, nowUtc: now, tzOffsetMinutes: tz);
    expect(q.newCardsPausedForBacklog, isTrue);
    expect(q.newCards, isEmpty);
  });

  test('suspended cards are ignored', () {
    final q = builder().build(cards: [
      qc('a', 'a', reviewCard(stability: 3, daysAgo: 5), suspended: true),
    ], nowUtc: now, tzOffsetMinutes: tz);
    expect(q.dueCount, 0);
  });
}

extension on CardState {
  CardState copyWithDue(DateTime due) => CardState(
        status: status,
        step: step,
        stability: stability,
        difficulty: difficulty,
        due: due,
        lastReview: lastReview,
        lastRating: lastRating,
        reps: reps,
        lapses: lapses,
      );
}
