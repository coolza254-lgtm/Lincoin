import 'dart:math' as math;

import 'ledger.dart';

class ChallengeTier {
  final String id;
  final double multiplier;

  /// Win probability the threshold is calibrated to.
  final double targetWinRate;

  const ChallengeTier(this.id, this.multiplier, this.targetWinRate);

  /// Expected coins back per coin staked when calibration is accurate.
  double get expectedReturn => multiplier * targetWinRate;
}

class ChallengeConfig {
  final int version;
  final List<ChallengeTier> tiers;
  final int minStake;
  final int maxStake;
  final double maxStakeFractionOfBalance;
  final int maxActive;

  /// Rounds of history used to calibrate thresholds.
  final int historyWindow;
  final int minHistory;

  const ChallengeConfig({
    this.version = 1,
    this.tiers = const [
      ChallengeTier('easy', 1.3, 0.75),
      ChallengeTier('normal', 2.0, 0.48),
      ChallengeTier('hard', 3.5, 0.27),
      ChallengeTier('brutal', 6.0, 0.15),
    ],
    this.minStake = 20,
    this.maxStake = 1000,
    this.maxStakeFractionOfBalance = 0.30,
    this.maxActive = 1,
    this.historyWindow = 20,
    this.minHistory = 5,
  });

  ChallengeTier tier(String id) => tiers.firstWhere((t) => t.id == id);

  Map<String, Object?> toJson() => {
        'version': version,
        'tiers': [
          for (final t in tiers)
            {
              'id': t.id,
              'multiplier': t.multiplier,
              'targetWinRate': t.targetWinRate
            }
        ],
        'minStake': minStake,
        'maxStake': maxStake,
        'maxStakeFractionOfBalance': maxStakeFractionOfBalance,
        'maxActive': maxActive,
        'historyWindow': historyWindow,
        'minHistory': minHistory,
      };

  factory ChallengeConfig.fromJson(Map<String, Object?> j) {
    int i(String k) => (j[k] as num).toInt();
    return ChallengeConfig(
      version: i('version'),
      tiers: [
        for (final t
            in (j['tiers'] as List<Object?>).cast<Map<String, Object?>>())
          ChallengeTier(t['id'] as String, (t['multiplier'] as num).toDouble(),
              (t['targetWinRate'] as num).toDouble())
      ],
      minStake: i('minStake'),
      maxStake: i('maxStake'),
      maxStakeFractionOfBalance:
          (j['maxStakeFractionOfBalance'] as num).toDouble(),
      maxActive: i('maxActive'),
      historyWindow: i('historyWindow'),
      minHistory: i('minHistory'),
    );
  }
}

class ChallengeRules {
  final ChallengeConfig config;
  const ChallengeRules([this.config = const ChallengeConfig()]);

  /// Largest stake allowed for [balance]; below [ChallengeConfig.minStake]
  /// means the learner cannot start a challenge.
  int maxStakeFor(int balance) => math.min(
      config.maxStake, (balance * config.maxStakeFractionOfBalance).floor());

  bool canStart(
          {required int balance,
          required int stake,
          required int activeCount}) =>
      activeCount < config.maxActive &&
      stake >= config.minStake &&
      stake <= maxStakeFor(balance);

  int payoutFor(int stake, String tierId) =>
      (stake * config.tier(tierId).multiplier).round();

  /// Threshold on a score where higher is better (e.g. correct answers in 60
  /// seconds) so the learner's recent rounds beat it with roughly the tier's
  /// target win rate. Returns [fallback] until enough history exists.
  num threshold({
    required List<num> recentScores,
    required String tierId,
    required num fallback,
    bool integer = true,
  }) {
    final recent = recentScores.length > config.historyWindow
        ? recentScores.sublist(recentScores.length - config.historyWindow)
        : recentScores;
    if (recent.length < config.minHistory) return fallback;
    final sorted = [...recent]..sort();
    final p = 1 - config.tier(tierId).targetWinRate;
    // Linear-interpolated quantile.
    final pos = p * (sorted.length - 1);
    final lo = pos.floor();
    final hi = math.min(lo + 1, sorted.length - 1);
    final q = sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
    return integer ? q.ceil() : q;
  }

  LedgerEntry stakeEntry({
    required String id,
    required String challengeId,
    required int stake,
    required DateTime nowUtc,
    required int studyDay,
  }) =>
      LedgerEntry(
        id: id,
        tsUtc: nowUtc,
        delta: -stake,
        reason: LedgerReason.challengeStake,
        idempotencyKey: 'challenge_stake:$challengeId',
        refId: challengeId,
        studyDay: studyDay,
      );

  /// Payout on a win (stake back plus winnings). Losing or forfeiting
  /// produces no entry.
  LedgerEntry winEntry({
    required String id,
    required String challengeId,
    required int stake,
    required String tierId,
    required DateTime nowUtc,
    required int studyDay,
  }) =>
      LedgerEntry(
        id: id,
        tsUtc: nowUtc,
        delta: payoutFor(stake, tierId),
        reason: LedgerReason.challengeWin,
        idempotencyKey: 'challenge_win:$challengeId',
        refId: challengeId,
        studyDay: studyDay,
      );
}
