import 'dart:math' as math;

import '../srs/card_state.dart';
import '../srs/mastery.dart';
import '../srs/scheduler.dart';

/// A review log row, as much as metrics need.
class ReviewRecord {
  final String cardId;
  final String deck;
  final DateTime tsUtc;
  final int studyDay;
  final CardStatus statusBefore;
  final Rating rating;
  final double? rPredicted;
  final int responseMs;

  const ReviewRecord({
    required this.cardId,
    required this.deck,
    required this.tsUtc,
    required this.studyDay,
    required this.statusBefore,
    required this.rating,
    required this.rPredicted,
    required this.responseMs,
  });
}

/// A card with the item (word / grammar point) and level it belongs to.
class TrackedCard {
  final String cardId;
  final String itemId;
  final String level;
  final CardState state;
  const TrackedCard(this.cardId, this.itemId, this.level, this.state);
}

class CalibrationBin {
  final double lower;
  final double upper;
  final int count;
  final double meanPredicted;
  final double actual;
  const CalibrationBin(
      this.lower, this.upper, this.count, this.meanPredicted, this.actual);
}

/// All progress numbers derive from card state and the review log with fixed
/// rules, so they can be recomputed at any time.
class Metrics {
  final SrsScheduler scheduler;
  final MasteryRule mastery;
  const Metrics(this.scheduler, [this.mastery = const MasteryRule()]);

  /// Recall probability per item: the weakest enabled facet, because an item
  /// counts as known only if every practised direction is recalled.
  Map<String, double> itemRetrievability(
      Iterable<TrackedCard> cards, DateTime nowUtc) {
    final out = <String, double>{};
    for (final c in cards) {
      final r = scheduler.retrievability(c.state, nowUtc);
      out[c.itemId] =
          out.containsKey(c.itemId) ? math.min(out[c.itemId]!, r) : r;
    }
    return out;
  }

  /// Expected number of items recalled right now (Σ R).
  double expectedKnown(Iterable<TrackedCard> cards, DateTime nowUtc) =>
      itemRetrievability(cards, nowUtc).values.fold(0.0, (a, b) => a + b);

  /// Σ R of a level's items ÷ all items in that level (unstarted count 0).
  double coverage({
    required Iterable<TrackedCard> cards,
    required int totalItemsInLevel,
    required DateTime nowUtc,
  }) {
    if (totalItemsInLevel == 0) return 0;
    return expectedKnown(cards, nowUtc) / totalItemsInLevel;
  }

  /// Items whose every card is currently mastered.
  int masteredItems(Iterable<TrackedCard> cards) {
    final byItem = <String, bool>{};
    for (final c in cards) {
      final m = mastery.isMastered(c.state);
      byItem[c.itemId] = (byItem[c.itemId] ?? true) && m;
    }
    return byItem.values.where((m) => m).length;
  }

  /// Share of passed answers among scheduled reviews of review-state cards
  /// (learning steps excluded). Null when there is no data.
  double? trueRetention(Iterable<ReviewRecord> log,
      {int? fromDay, int? toDay}) {
    var n = 0;
    var pass = 0;
    for (final r in log) {
      if (r.statusBefore != CardStatus.review) continue;
      if (fromDay != null && r.studyDay < fromDay) continue;
      if (toDay != null && r.studyDay > toDay) continue;
      n++;
      if (r.rating.isPass) pass++;
    }
    return n == 0 ? null : pass / n;
  }

  /// Predicted vs actual recall, in bins of predicted probability.
  List<CalibrationBin> calibration(Iterable<ReviewRecord> log,
      {double binWidth = 0.05}) {
    final bins = (1 / binWidth).round();
    final count = List.filled(bins, 0);
    final sumPred = List.filled(bins, 0.0);
    final pass = List.filled(bins, 0);
    for (final r in log) {
      final p = r.rPredicted;
      if (p == null || r.statusBefore != CardStatus.review) continue;
      final i = math.min((p / binWidth).floor(), bins - 1);
      count[i]++;
      sumPred[i] += p;
      if (r.rating.isPass) pass[i]++;
    }
    return [
      for (var i = 0; i < bins; i++)
        if (count[i] > 0)
          CalibrationBin(i * binWidth, (i + 1) * binWidth, count[i],
              sumPred[i] / count[i], pass[i] / count[i]),
    ];
  }

  /// Log loss of predicted recall on review-state answers; lower is better.
  /// Used to accept or reject new FSRS parameters.
  double? logLoss(Iterable<ReviewRecord> log) {
    var n = 0;
    var sum = 0.0;
    for (final r in log) {
      final p = r.rPredicted;
      if (p == null || r.statusBefore != CardStatus.review) continue;
      final q = p.clamp(1e-6, 1 - 1e-6);
      sum += r.rating.isPass ? -math.log(q) : -math.log(1 - q);
      n++;
    }
    return n == 0 ? null : sum / n;
  }
}
