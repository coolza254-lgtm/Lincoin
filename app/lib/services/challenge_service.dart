import 'dart:convert';

import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/study_repo.dart';
import '../data/user_db.dart';
import 'study_service.dart';

/// The challenges on offer (docs/05-modes.md). Scores are "higher is
/// better"; a round is won when score ≥ threshold.
enum ChallengeType {
  /// Correct answers in 60 seconds (multiple choice).
  speed(fallback: {'easy': 8, 'normal': 12, 'hard': 15, 'brutal': 18}),

  /// Correct answers in a row; the first mistake ends the round.
  streak(fallback: {'easy': 5, 'normal': 8, 'hard': 12, 'brutal': 16}),

  /// 10 questions from weak items; score = correct answers.
  weak(fallback: {'easy': 6, 'normal': 8, 'hard': 9, 'brutal': 10}),

  /// Clear the day's due cards on N of the next 7 days (not skill-calibrated,
  /// so it has its own, lower multipliers and stake cap).
  weekly(fallback: {'easy': 4, 'normal': 5, 'hard': 6, 'brutal': 7});

  const ChallengeType({required this.fallback});
  final Map<String, int> fallback;

  static ChallengeType? tryParse(String s) =>
      values.where((t) => t.name == s).firstOrNull;

  int get maxScore => switch (this) {
    speed => 60,
    streak => 40,
    weak => 10,
    weekly => 7,
  };
}

/// Weekly challenge: fixed thresholds, so multipliers stay modest.
const weeklyMultipliers = {
  'easy': 1.2,
  'normal': 1.5,
  'hard': 2.0,
  'brutal': 2.5,
};
const weeklyMaxStake = 200;

class ChallengeRecord {
  final String id;
  final ChallengeType type;
  final String tier;
  final int stake;
  final double multiplier;
  final int threshold;
  final DateTime startedAt;
  final int startDay;
  final String result;
  final num? score;

  const ChallengeRecord({
    required this.id,
    required this.type,
    required this.tier,
    required this.stake,
    required this.multiplier,
    required this.threshold,
    required this.startedAt,
    required this.startDay,
    required this.result,
    this.score,
  });

  bool get active => result == 'active';
  int get payout => (stake * multiplier).round();
}

/// Offer shown before starting: what must be reached and what is at stake.
class ChallengeOffer {
  final ChallengeType type;
  final String tier;
  final int threshold;
  final double multiplier;
  final int minStake;
  final int maxStake;

  /// Threshold still uses the default (fewer than minHistory rounds).
  final bool calibrating;

  const ChallengeOffer({
    required this.type,
    required this.tier,
    required this.threshold,
    required this.multiplier,
    required this.minStake,
    required this.maxStake,
    required this.calibrating,
  });

  bool get affordable => maxStake >= minStake;
}

/// Starts, finishes and settles challenges; all Lincoin moves go through
/// the ledger with one idempotency key per challenge.
class ChallengeService {
  final StudyService study;
  ChallengeService(this.study);

  static const minItemsToUnlock = 20;

  UserDb get _db => study.db;
  ChallengeRules get rules => ChallengeRules(study.config.challenge);

  List<ChallengeRecord> history({ChallengeType? type, int limit = 50}) => [
    for (final r in _db.db.select(
      'SELECT * FROM challenges ${type == null ? '' : 'WHERE type = ?'} '
      'ORDER BY started_at DESC LIMIT ?',
      [if (type != null) type.name, limit],
    ))
      if (ChallengeType.tryParse(r['type'] as String) case final t?)
        ChallengeRecord(
          id: r['id'] as String,
          type: t,
          tier: r['tier'] as String,
          stake: r['stake'] as int,
          multiplier: (r['multiplier'] as num).toDouble(),
          threshold:
              (jsonDecode(r['target_json'] as String)
                      as Map<String, dynamic>)['threshold']
                  as int,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            r['started_at'] as int,
            isUtc: true,
          ),
          startDay:
              (jsonDecode(r['target_json'] as String)
                      as Map<String, dynamic>)['startDay']
                  as int? ??
              0,
          result: r['result'] as String,
          score: r['score'] as num?,
        ),
  ];

  List<ChallengeRecord> active() =>
      history(limit: 20).where((c) => c.active).toList();

  /// Scores of finished rounds of [type], oldest first (for calibration).
  List<num> recentScores(ChallengeType type) => [
    for (final c in history(
      type: type,
      limit: rules.config.historyWindow,
    ).reversed)
      if (!c.active && c.score != null) c.score!,
  ];

  ChallengeOffer offer(ChallengeType type, String tier, int balance) {
    if (type == ChallengeType.weekly) {
      final max = rules.maxStakeFor(balance).clamp(0, weeklyMaxStake);
      return ChallengeOffer(
        type: type,
        tier: tier,
        threshold: type.fallback[tier]!,
        multiplier: weeklyMultipliers[tier]!,
        minStake: rules.config.minStake,
        maxStake: max,
        calibrating: false,
      );
    }
    final scores = recentScores(type);
    final t = rules.threshold(
      recentScores: scores,
      tierId: tier,
      fallback: type.fallback[tier]!,
    );
    return ChallengeOffer(
      type: type,
      tier: tier,
      // At least 1, never above what the round allows.
      threshold: t.toInt().clamp(1, type.maxScore),
      multiplier: rules.config.tier(tier).multiplier,
      minStake: rules.config.minStake,
      maxStake: rules.maxStakeFor(balance),
      calibrating: scores.length < rules.config.minHistory,
    );
  }

  /// Takes the stake and records the challenge. Weekly challenges run next
  /// to one skill challenge; otherwise only one may be active.
  ChallengeRecord start(ChallengeOffer o, int stake) {
    final now = study.clock.nowUtc();
    final day = study.studyDay(now);
    final ledger = LedgerRepo(_db);
    final activeSame = active()
        .where(
          (c) =>
              (c.type == ChallengeType.weekly) ==
              (o.type == ChallengeType.weekly),
        )
        .length;
    if (activeSame >= rules.config.maxActive) {
      throw StateError('มีชาเลนจ์ที่ยังไม่จบอยู่');
    }
    if (stake < o.minStake || stake > o.maxStake) {
      throw StateError('เดิมพันต้องอยู่ระหว่าง ${o.minStake}–${o.maxStake}');
    }
    final id = UserDb.newId();
    final stakeId = UserDb.newId();
    _db.tx(() {
      ledger.insertAll([
        rules.stakeEntry(
          id: stakeId,
          challengeId: id,
          stake: stake,
          nowUtc: now,
          studyDay: day,
        ),
      ]);
      _db.db.execute(
        'INSERT INTO challenges(id, type, tier, stake, multiplier, '
        'target_json, started_at, result, stake_ledger_id) '
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?)",
        [
          id,
          o.type.name,
          o.tier,
          stake,
          o.multiplier,
          jsonEncode({'threshold': o.threshold, 'startDay': day}),
          now.millisecondsSinceEpoch,
          stakeId,
        ],
      );
    });
    return byId(id);
  }

  ChallengeRecord byId(String id) =>
      history(limit: 1 << 30).firstWhere((c) => c.id == id);

  /// Ends a round with [score]; pays stake × multiplier on a win.
  ChallengeRecord finish(String id, num score) {
    final c = byId(id);
    if (!c.active) return c;
    final won = score >= c.threshold;
    final now = study.clock.nowUtc();
    _db.tx(() {
      String? payoutId;
      if (won) {
        payoutId = UserDb.newId();
        LedgerRepo(_db).insertAll([
          LedgerEntry(
            id: payoutId,
            tsUtc: now,
            delta: c.payout,
            reason: LedgerReason.challengeWin,
            idempotencyKey: 'challenge_win:$id',
            refId: id,
            studyDay: study.studyDay(now),
          ),
        ]);
      }
      _db.db.execute(
        'UPDATE challenges SET result = ?, score = ?, finished_at = ?, '
        'payout_ledger_id = ? WHERE id = ?',
        [won ? 'won' : 'lost', score, now.millisecondsSinceEpoch, payoutId, id],
      );
    });
    return byId(id);
  }

  /// Leaving a round early counts as a loss (stake is not returned).
  void forfeit(String id) {
    _db.db.execute(
      "UPDATE challenges SET result = 'forfeited', finished_at = ? "
      "WHERE id = ? AND result = 'active'",
      [study.clock.nowUtc().millisecondsSinceEpoch, id],
    );
  }

  /// At app start: skill rounds left active (app closed mid-round) are
  /// forfeited.
  int forfeitAbandoned() {
    var n = 0;
    for (final c in active()) {
      if (c.type != ChallengeType.weekly) {
        forfeit(c.id);
        n++;
      }
    }
    return n;
  }

  /// Days (of the 7 starting at [c.startDay]) on which the vocab deck was
  /// cleared.
  int weeklyProgress(ChallengeRecord c) =>
      _db.db
              .select(
                'SELECT count(*) FROM coin_ledger WHERE reason = ? '
                'AND idempotency_key LIKE ? AND study_day BETWEEN ? AND ?',
                [
                  LedgerReason.dailyClear,
                  'daily_clear:$vocabDeck:%',
                  c.startDay,
                  c.startDay + 6,
                ],
              )
              .first
              .columnAt(0)
          as int;

  /// Settles weekly challenges: won as soon as the target is reached, lost
  /// once it can no longer be reached.
  List<ChallengeRecord> settleWeekly() {
    final today = study.studyDay();
    final settled = <ChallengeRecord>[];
    for (final c in active().where((c) => c.type == ChallengeType.weekly)) {
      final done = weeklyProgress(c);
      final lastDay = c.startDay + 6;
      final daysLeft = (lastDay - today).clamp(0, 7);
      // Today still counts as open until it is cleared.
      final todayCleared =
          today <= lastDay &&
          LedgerRepo(_db).has('daily_clear:$vocabDeck:$today');
      final possible =
          done + daysLeft + (todayCleared || today > lastDay ? 0 : 1);
      if (done >= c.threshold || possible < c.threshold || today > lastDay) {
        settled.add(finish(c.id, done));
      }
    }
    return settled;
  }
}
