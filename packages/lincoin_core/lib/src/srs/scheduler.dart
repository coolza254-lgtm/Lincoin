import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as fsrs;

import '../util/hash.dart';
import 'card_state.dart';
import 'srs_config.dart';

/// Result of applying one graded answer to a card.
class ReviewOutcome {
  final CardState before;
  final CardState after;

  /// Predicted recall probability at answer time; null for a card never
  /// reviewed before. Logged for calibration charts and the optimizer.
  final double? retrievabilityBefore;

  /// Whole days since the previous review (0 for the first review).
  final int elapsedDays;

  const ReviewOutcome({
    required this.before,
    required this.after,
    required this.retrievabilityBefore,
    required this.elapsedDays,
  });

  /// Card left the (initial) learning steps for the first time.
  bool get graduated =>
      (before.status == CardStatus.newCard ||
          before.status == CardStatus.learning) &&
      after.status == CardStatus.review;

  /// A review-state card was forgotten.
  bool get lapsed => after.lapses > before.lapses;
}

/// One answer as stored in the review log; enough to rebuild state.
class ReviewInput {
  final Rating rating;
  final DateTime reviewedAtUtc;
  const ReviewInput(this.rating, this.reviewedAtUtc);
}

/// FSRS scheduler wrapper.
///
/// Deterministic: time is always passed in and fuzz is seeded from the card
/// id and repetition count, so replaying the review log reproduces the
/// stored state exactly.
class SrsScheduler {
  final SrsConfig config;
  final fsrs.Scheduler _fsrs;

  SrsScheduler(this.config)
      : _fsrs = fsrs.Scheduler(
          parameters: config.parameters,
          desiredRetention: config.desiredRetention,
          learningSteps: config.learningSteps,
          relearningSteps: config.relearningSteps,
          maximumInterval: config.maximumIntervalDays,
          // Fuzz is applied here, deterministically.
          enableFuzzing: false,
        );

  /// Probability of recall for [state] at [nowUtc]; 0 for unseen cards.
  double retrievability(CardState state, DateTime nowUtc) {
    _requireUtc(nowUtc);
    if (state.lastReview == null || state.stability == null) return 0;
    return _fsrs.getCardRetrievability(_toFsrs(state), currentDateTime: nowUtc);
  }

  ReviewOutcome review({
    required String cardId,
    required CardState state,
    required Rating rating,
    required DateTime nowUtc,
  }) {
    _requireUtc(nowUtc);
    final last = state.lastReview;
    if (last != null && nowUtc.isBefore(last)) {
      throw ArgumentError.value(
          nowUtc, 'nowUtc', 'is before the previous review ($last)');
    }

    final rBefore =
        state.lastReview == null ? null : retrievability(state, nowUtc);
    final elapsed = last == null ? 0 : nowUtc.difference(last).inDays;

    final result = _fsrs.reviewCard(
      _toFsrs(state.isNew ? CardState.initial : state, nowUtc),
      _toFsrsRating(rating),
      reviewDateTime: nowUtc,
    );
    var card = result.card;

    if (config.enableFuzz && card.state == fsrs.State.review) {
      final days = card.due.difference(nowUtc).inDays;
      final fuzzed = fuzzIntervalDays(days, '$cardId#${state.reps}');
      card = card.copyWith(due: nowUtc.add(Duration(days: fuzzed)));
    }

    final after = CardState(
      status: _fromFsrsState(card.state),
      step: card.step,
      stability: card.stability,
      difficulty: card.difficulty,
      due: card.due,
      lastReview: card.lastReview,
      lastRating: rating,
      reps: state.reps + 1,
      lapses: state.lapses +
          (state.status == CardStatus.review && rating == Rating.again ? 1 : 0),
    );

    return ReviewOutcome(
      before: state,
      after: after,
      retrievabilityBefore: rBefore,
      elapsedDays: elapsed,
    );
  }

  /// Rebuilds a card's state from its review log (oldest first).
  CardState replay(String cardId, Iterable<ReviewInput> log) {
    var state = CardState.initial;
    for (final entry in log) {
      state = review(
        cardId: cardId,
        state: state,
        rating: entry.rating,
        nowUtc: entry.reviewedAtUtc,
      ).after;
    }
    return state;
  }

  bool isLeech(CardState state) => state.lapses >= config.leechThreshold;

  /// Spreads review intervals so cards learned together do not stay clumped.
  /// Same ranges as FSRS reference implementations; the random draw comes from
  /// [seedKey] so the result is reproducible.
  int fuzzIntervalDays(int intervalDays, String seedKey) {
    if (intervalDays < 3) return intervalDays;
    var delta = 1.0;
    const ranges = [
      (2.5, 7.0, 0.15),
      (7.0, 20.0, 0.1),
      (20.0, double.infinity, 0.05)
    ];
    for (final (start, end, factor) in ranges) {
      delta += factor *
          math.max(math.min(intervalDays.toDouble(), end) - start, 0.0);
    }
    var minIvl = math.max(2, (intervalDays - delta).round());
    final maxIvl =
        math.min((intervalDays + delta).round(), config.maximumIntervalDays);
    minIvl = math.min(minIvl, maxIvl);
    final u = unitFromKey(seedKey);
    return minIvl + (u * (maxIvl - minIvl + 1)).floor();
  }

  static void _requireUtc(DateTime t) {
    if (!t.isUtc) throw ArgumentError.value(t, 'time', 'must be UTC');
  }

  static fsrs.Card _toFsrs(CardState s, [DateTime? nowForNew]) {
    if (s.isNew) {
      return fsrs.Card(
          cardId: 0, state: fsrs.State.learning, step: 0, due: nowForNew);
    }
    return fsrs.Card(
      cardId: 0,
      state: switch (s.status) {
        CardStatus.learning => fsrs.State.learning,
        CardStatus.review => fsrs.State.review,
        CardStatus.relearning => fsrs.State.relearning,
        CardStatus.newCard => throw StateError('unreachable'),
      },
      step: s.step,
      stability: s.stability,
      difficulty: s.difficulty,
      due: s.due,
      lastReview: s.lastReview,
    );
  }

  static CardStatus _fromFsrsState(fsrs.State s) => switch (s) {
        fsrs.State.learning => CardStatus.learning,
        fsrs.State.review => CardStatus.review,
        fsrs.State.relearning => CardStatus.relearning,
      };

  static fsrs.Rating _toFsrsRating(Rating r) => fsrs.Rating.fromValue(r.value);
}
