import 'dart:math' as math;

import '../srs/card_state.dart';
import 'ledger.dart';

/// All reward numbers live here as data so they can be rebalanced (and
/// versioned) without code changes.
class RewardConfig {
  final int version;
  final int reviewCorrect;
  final int relearnCorrect;
  final int learned;
  final int mastered;
  final int dailyClear;

  /// (coverage fraction, bonus), ascending.
  final List<(double, int)> coverageMilestones;
  final int dailyReviewCap;

  /// Answers faster than this earn nothing (likely a mis-tap or cheating).
  final int minHumanResponseMs;

  final int practiceCorrect;
  final double practiceWeakMultiplier;
  final int practiceComboEvery;
  final int practiceComboBonus;
  final int practiceMaxPayoutsPerCardPerDay;

  /// Diminishing returns on raw practice points per day: (upTo, rate).
  final List<(double, double)> practiceTiers;

  const RewardConfig({
    this.version = 1,
    this.reviewCorrect = 2,
    this.relearnCorrect = 3,
    this.learned = 5,
    this.mastered = 10,
    this.dailyClear = 20,
    this.coverageMilestones = const [
      (0.25, 100),
      (0.5, 250),
      (0.75, 500),
      (1.0, 1000)
    ],
    this.dailyReviewCap = 300,
    this.minHumanResponseMs = 400,
    this.practiceCorrect = 1,
    this.practiceWeakMultiplier = 1.5,
    this.practiceComboEvery = 5,
    this.practiceComboBonus = 1,
    this.practiceMaxPayoutsPerCardPerDay = 3,
    this.practiceTiers = const [(100, 1.0), (200, 0.5), (double.infinity, 0.1)],
  });

  Map<String, Object?> toJson() => {
        'version': version,
        'reviewCorrect': reviewCorrect,
        'relearnCorrect': relearnCorrect,
        'learned': learned,
        'mastered': mastered,
        'dailyClear': dailyClear,
        'coverageMilestones': [
          for (final (at, bonus) in coverageMilestones)
            {'at': at, 'bonus': bonus}
        ],
        'dailyReviewCap': dailyReviewCap,
        'minHumanResponseMs': minHumanResponseMs,
        'practiceCorrect': practiceCorrect,
        'practiceWeakMultiplier': practiceWeakMultiplier,
        'practiceComboEvery': practiceComboEvery,
        'practiceComboBonus': practiceComboBonus,
        'practiceMaxPayoutsPerCardPerDay': practiceMaxPayoutsPerCardPerDay,
        // null upper bound = no limit (JSON has no infinity)
        'practiceTiers': [
          for (final (upTo, rate) in practiceTiers)
            {'upTo': upTo.isFinite ? upTo : null, 'rate': rate}
        ],
      };

  factory RewardConfig.fromJson(Map<String, Object?> j) {
    int i(String k) => (j[k] as num).toInt();
    return RewardConfig(
      version: i('version'),
      reviewCorrect: i('reviewCorrect'),
      relearnCorrect: i('relearnCorrect'),
      learned: i('learned'),
      mastered: i('mastered'),
      dailyClear: i('dailyClear'),
      coverageMilestones: [
        for (final m in (j['coverageMilestones'] as List<Object?>)
            .cast<Map<String, Object?>>())
          ((m['at'] as num).toDouble(), (m['bonus'] as num).toInt())
      ],
      dailyReviewCap: i('dailyReviewCap'),
      minHumanResponseMs: i('minHumanResponseMs'),
      practiceCorrect: i('practiceCorrect'),
      practiceWeakMultiplier: (j['practiceWeakMultiplier'] as num).toDouble(),
      practiceComboEvery: i('practiceComboEvery'),
      practiceComboBonus: i('practiceComboBonus'),
      practiceMaxPayoutsPerCardPerDay: i('practiceMaxPayoutsPerCardPerDay'),
      practiceTiers: [
        for (final t in (j['practiceTiers'] as List<Object?>)
            .cast<Map<String, Object?>>())
          (
            (t['upTo'] as num?)?.toDouble() ?? double.infinity,
            (t['rate'] as num).toDouble()
          )
      ],
    );
  }
}

/// A graded answer in the main (FSRS) modes.
class ReviewRewardInput {
  final String reviewLogId;
  final String cardId;
  final String deck;
  final CardStatus statusBefore;
  final Rating rating;
  final int responseMs;
  final bool graduated;

  /// The card satisfies the mastery rule for the first time ever.
  final bool firstMastered;

  const ReviewRewardInput({
    required this.reviewLogId,
    required this.cardId,
    required this.deck,
    required this.statusBefore,
    required this.rating,
    required this.responseMs,
    this.graduated = false,
    this.firstMastered = false,
  });
}

class PracticeRewardInput {
  final String practiceLogId;
  final String cardId;
  final bool isCorrect;
  final int responseMs;
  final bool isWeakItem;

  /// Consecutive correct answers in this round including this one.
  final int comboCount;

  const PracticeRewardInput({
    required this.practiceLogId,
    required this.cardId,
    required this.isCorrect,
    required this.responseMs,
    this.isWeakItem = false,
    this.comboCount = 0,
  });
}

/// Produces ledger entries for learning events. Stateless: today's totals
/// are read from the ledger by the caller.
class RewardEngine {
  final RewardConfig config;
  final String Function() newId;

  RewardEngine({this.config = const RewardConfig(), required this.newId});

  List<LedgerEntry> forReview(
    ReviewRewardInput e, {
    required DateTime nowUtc,
    required int studyDay,
    required DailyTotals today,
  }) {
    final out = <LedgerEntry>[];
    LedgerEntry entry(int delta, String reason, String key, [String? ref]) =>
        LedgerEntry(
          id: newId(),
          tsUtc: nowUtc,
          delta: delta,
          reason: reason,
          idempotencyKey: key,
          refId: ref,
          studyDay: studyDay,
        );

    final human = e.responseMs >= config.minHumanResponseMs;
    if (human &&
        e.rating.isPass &&
        (e.statusBefore == CardStatus.review ||
            e.statusBefore == CardStatus.relearning)) {
      final relearn = e.statusBefore == CardStatus.relearning;
      final base = relearn ? config.relearnCorrect : config.reviewCorrect;
      final room = math.max(0, config.dailyReviewCap - today.reviewCoins);
      final amount = math.min(base, room);
      if (amount > 0) {
        out.add(entry(
            amount,
            relearn ? LedgerReason.relearn : LedgerReason.review,
            'review:${e.reviewLogId}',
            e.reviewLogId));
      }
    }
    if (e.graduated) {
      out.add(entry(config.learned, LedgerReason.learned, 'learned:${e.cardId}',
          e.cardId));
    }
    if (e.firstMastered) {
      out.add(entry(config.mastered, LedgerReason.mastered,
          'mastered:${e.cardId}', e.cardId));
    }
    return out;
  }

  /// Bonus for finishing every due card of [deck] today.
  LedgerEntry dailyClear({
    required String deck,
    required DateTime nowUtc,
    required int studyDay,
  }) =>
      LedgerEntry(
        id: newId(),
        tsUtc: nowUtc,
        delta: config.dailyClear,
        reason: LedgerReason.dailyClear,
        idempotencyKey: 'daily_clear:$deck:$studyDay',
        studyDay: studyDay,
      );

  /// Entries for every milestone reached; the ledger drops ones already paid.
  List<LedgerEntry> forCoverage({
    required String deck,
    required String level,
    required double coverage,
    required DateTime nowUtc,
    required int studyDay,
  }) {
    return [
      for (final (m, bonus) in config.coverageMilestones)
        if (coverage >= m)
          LedgerEntry(
            id: newId(),
            tsUtc: nowUtc,
            delta: bonus,
            reason: LedgerReason.coverage,
            idempotencyKey: 'coverage:$deck:$level:${(m * 100).round()}',
            studyDay: studyDay,
          ),
    ];
  }

  /// Practice payout with diminishing returns. Returns null when the answer
  /// earns nothing and does not need recording.
  LedgerEntry? forPractice(
    PracticeRewardInput e, {
    required DateTime nowUtc,
    required int studyDay,
    required DailyTotals today,
  }) {
    if (!e.isCorrect || e.responseMs < config.minHumanResponseMs) return null;
    final paidForCard = today.practicePayoutsByCard[e.cardId] ?? 0;
    if (paidForCard >= config.practiceMaxPayoutsPerCardPerDay) return null;

    var raw = config.practiceCorrect *
        (e.isWeakItem ? config.practiceWeakMultiplier : 1.0);
    if (config.practiceComboEvery > 0 &&
        e.comboCount > 0 &&
        e.comboCount % config.practiceComboEvery == 0) {
      raw += config.practiceComboBonus;
    }
    final before = _effective(today.practiceRaw).floor();
    final after = _effective(today.practiceRaw + raw).floor();
    return LedgerEntry(
      id: newId(),
      tsUtc: nowUtc,
      delta: after - before,
      reason: LedgerReason.practice,
      idempotencyKey: 'practice:${e.practiceLogId}',
      refId: e.practiceLogId,
      studyDay: studyDay,
      meta: {'raw': raw, 'cardId': e.cardId},
    );
  }

  /// Coins paid for [raw] practice points in one day (piecewise linear).
  double _effective(double raw) {
    var paid = 0.0;
    var lower = 0.0;
    for (final (upTo, rate) in config.practiceTiers) {
      if (raw <= lower) break;
      paid += (math.min(raw, upTo) - lower) * rate;
      lower = upTo;
    }
    return paid;
  }
}
