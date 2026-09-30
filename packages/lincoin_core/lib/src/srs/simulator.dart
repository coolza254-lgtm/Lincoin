import 'dart:math';

import 'card_state.dart';
import 'scheduler.dart';
import 'srs_config.dart';

class SimulationResult {
  /// Review-state answers per day (learning steps excluded).
  final List<int> dailyReviews;

  /// New cards introduced per day.
  final List<int> dailyNew;
  final double retention;
  final int totalAnswers;

  const SimulationResult(
      this.dailyReviews, this.dailyNew, this.retention, this.totalAnswers);

  double averageReviews(int fromDay, int toDay) {
    final slice =
        dailyReviews.sublist(fromDay, min(toDay, dailyReviews.length));
    return slice.isEmpty ? 0 : slice.reduce((a, b) => a + b) / slice.length;
  }
}

/// Workload simulator: a learner who studies daily and whose recall follows
/// the model's own prediction. Used by the settings screen to preview the
/// cost of a desired retention / new-cards-per-day choice, and by tests.
SimulationResult simulateWorkload({
  required SrsConfig config,
  required int days,
  required int newPerDay,

  /// Stop after this many new cards (e.g. size of the remaining deck).
  int? totalNewCards,
  double learningPassRate = 0.85,
  double hardShare = 0.1,
  int seed = 1,
}) {
  final rnd = Random(seed);
  final s = SrsScheduler(config);
  final start = DateTime.utc(2025, 1, 1, 12);
  final cards = <CardState>[];
  final dailyReviews = <int>[];
  final dailyNew = <int>[];
  var due = 0;
  var passed = 0;
  var total = 0;

  for (var day = 0; day < days; day++) {
    final dayStart = start.add(Duration(days: day));
    final dayEnd = dayStart.add(const Duration(hours: 12));

    final remaining = totalNewCards == null
        ? newPerDay
        : min(newPerDay, totalNewCards - cards.length);
    for (var n = 0; n < remaining; n++) {
      cards.add(CardState.initial);
    }
    dailyNew.add(max(0, remaining));

    final pending = <int>[
      for (var i = 0; i < cards.length; i++)
        if (cards[i].isNew || !cards[i].due!.isAfter(dayEnd)) i
    ];
    DateTime timeOf(int i) {
      final c = cards[i];
      final t = c.isNew ? dayStart : c.due!;
      return t.isBefore(dayStart) ? dayStart : t;
    }

    var reviewsToday = 0;
    while (pending.isNotEmpty) {
      var best = 0;
      for (var k = 1; k < pending.length; k++) {
        if (timeOf(pending[k]).isBefore(timeOf(pending[best]))) best = k;
      }
      final i = pending.removeAt(best);
      final st = cards[i];
      final now = timeOf(i);
      final isReview = st.status == CardStatus.review;
      final p = isReview ? s.retrievability(st, now) : learningPassRate;
      final pass = rnd.nextDouble() < p;
      final rating = !pass
          ? Rating.again
          : (rnd.nextDouble() < hardShare ? Rating.hard : Rating.good);
      final after =
          s.review(cardId: 'c$i', state: st, rating: rating, nowUtc: now).after;
      cards[i] = after;
      total++;
      if (isReview) {
        due++;
        if (pass) passed++;
        reviewsToday++;
      }
      if (!after.due!.isAfter(dayEnd)) pending.add(i);
    }
    dailyReviews.add(reviewsToday);
  }
  return SimulationResult(
      dailyReviews, dailyNew, due == 0 ? 0 : passed / due, total);
}
