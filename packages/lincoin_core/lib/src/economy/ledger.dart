/// Append-only record of every Lincoin movement. The balance is always the
/// sum of entries; it is never stored on its own.
library;

class LedgerEntry {
  final String id;
  final DateTime tsUtc;
  final int delta;
  final String reason;

  /// Guarantees one payout per event (e.g. `review:<log id>`).
  final String idempotencyKey;
  final String? refId;
  final int studyDay;

  /// Extra data (e.g. raw practice points before diminishing returns).
  final Map<String, Object?> meta;

  const LedgerEntry({
    required this.id,
    required this.tsUtc,
    required this.delta,
    required this.reason,
    required this.idempotencyKey,
    required this.studyDay,
    this.refId,
    this.meta = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'tsUtc': tsUtc.toIso8601String(),
        'delta': delta,
        'reason': reason,
        'idempotencyKey': idempotencyKey,
        'refId': refId,
        'studyDay': studyDay,
        'meta': meta,
      };

  factory LedgerEntry.fromJson(Map<String, Object?> json) => LedgerEntry(
        id: json['id'] as String,
        tsUtc: DateTime.parse(json['tsUtc'] as String).toUtc(),
        delta: (json['delta'] as num).toInt(),
        reason: json['reason'] as String,
        idempotencyKey: json['idempotencyKey'] as String,
        refId: json['refId'] as String?,
        studyDay: (json['studyDay'] as num).toInt(),
        meta: Map<String, Object?>.from(
            (json['meta'] as Map<Object?, Object?>?) ?? const {}),
      );
}

/// Reasons written by the engines.
abstract final class LedgerReason {
  static const review = 'review';
  static const relearn = 'relearn';
  static const learned = 'learned';
  static const mastered = 'mastered';
  static const dailyClear = 'daily_clear';
  static const coverage = 'coverage';
  static const practice = 'practice';
  static const challengeStake = 'challenge_stake';
  static const challengeWin = 'challenge_win';
  static const challengeRefund = 'challenge_refund';
  static const redeem = 'redeem';

  static const reviewReasons = {review, relearn};
}

/// In-memory ledger with the same rules the database enforces.
class Ledger {
  final List<LedgerEntry> _entries = [];
  final Set<String> _keys = {};

  Ledger([Iterable<LedgerEntry> entries = const []]) {
    for (final e in entries) {
      add(e);
    }
  }

  List<LedgerEntry> get entries => List.unmodifiable(_entries);
  int get balance => _entries.fold(0, (sum, e) => sum + e.delta);

  bool contains(String idempotencyKey) => _keys.contains(idempotencyKey);

  /// Adds [entry]; returns false (and changes nothing) for a duplicate key
  /// or a spend that would make the balance negative.
  bool add(LedgerEntry entry) {
    if (_keys.contains(entry.idempotencyKey)) return false;
    if (entry.delta < 0 && balance + entry.delta < 0) return false;
    _entries.add(entry);
    _keys.add(entry.idempotencyKey);
    return true;
  }

  DailyTotals totalsFor(int studyDay) =>
      DailyTotals.fromEntries(_entries.where((e) => e.studyDay == studyDay));
}

/// What has already been earned today; input to the reward caps.
class DailyTotals {
  final int reviewCoins;

  /// Raw practice points before diminishing returns.
  final double practiceRaw;

  /// Practice payouts per card today.
  final Map<String, int> practicePayoutsByCard;

  const DailyTotals({
    this.reviewCoins = 0,
    this.practiceRaw = 0,
    this.practicePayoutsByCard = const {},
  });

  factory DailyTotals.fromEntries(Iterable<LedgerEntry> entries) {
    var review = 0;
    var raw = 0.0;
    final byCard = <String, int>{};
    for (final e in entries) {
      if (LedgerReason.reviewReasons.contains(e.reason)) review += e.delta;
      if (e.reason == LedgerReason.practice) {
        raw += (e.meta['raw'] as num?)?.toDouble() ?? e.delta.toDouble();
        final card = e.meta['cardId'] as String?;
        if (card != null) byCard[card] = (byCard[card] ?? 0) + 1;
      }
    }
    return DailyTotals(
        reviewCoins: review, practiceRaw: raw, practicePayoutsByCard: byCard);
  }
}
