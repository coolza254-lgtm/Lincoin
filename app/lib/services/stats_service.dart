import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import 'study_service.dart';

class LevelStats {
  final String level;
  final int total;
  final int started;
  final double expectedKnown;
  final int mastered;
  const LevelStats(
    this.level,
    this.total,
    this.started,
    this.expectedKnown,
    this.mastered,
  );
  double get coverage => total == 0 ? 0 : expectedKnown / total;
}

class DayCount {
  final int studyDay;
  final int reviews;
  final int passed;
  final int activeMs;
  const DayCount(this.studyDay, this.reviews, this.passed, this.activeMs);
}

/// Everything the stats tab shows. All numbers are recomputed from card
/// state and the logs with fixed rules (docs/07-progress-metrics.md).
class StatsData {
  final List<LevelStats> levels;
  final double expectedKnown;
  final int itemsStarted;
  final int masteredItems;

  /// Share of passed scheduled reviews in the last 30 days; null = no data.
  final double? trueRetention30;
  final int retentionSample30;
  final double targetRetention;
  final List<DayCount> last14Days;
  final int activeMsTotal7;

  /// Reviews due on each of the next 7 study days (index 0 = today).
  final List<int> forecast7;
  final List<CalibrationBin> calibration;
  final int calibrationSample;
  final double? logLoss;
  final int leeches;
  final int totalReviews;

  const StatsData({
    required this.levels,
    required this.expectedKnown,
    required this.itemsStarted,
    required this.masteredItems,
    required this.trueRetention30,
    required this.retentionSample30,
    required this.targetRetention,
    required this.last14Days,
    required this.activeMsTotal7,
    required this.forecast7,
    required this.calibration,
    required this.calibrationSample,
    required this.logLoss,
    required this.leeches,
    required this.totalReviews,
  });
}

class StatsService {
  final StudyService s;
  StatsService(this.s);

  StatsData compute() {
    final now = s.clock.nowUtc();
    final today = s.studyDay(now);
    final metrics = Metrics(s.scheduler, s.config.mastery);
    final tracked = s.trackedCards();
    final byLevel = <String, List<TrackedCard>>{};
    for (final c in tracked) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    final totals = s.catalog.itemsPerLevel(s.deck);
    final levels = [
      for (final l in s.deck == grammarDeck ? grammarLevels : vocabLevels)
        if (totals.containsKey(l))
          LevelStats(
            l,
            totals[l]!,
            (byLevel[l] ?? const []).map((c) => c.itemId).toSet().length,
            metrics.expectedKnown(byLevel[l] ?? const [], now),
            metrics.masteredItems(byLevel[l] ?? const []),
          ),
    ];

    final log = s.repo.reviewSummary(
      deck: s.deck,
      fromDay14: today - 13,
      fromDay30: today - 29,
    );
    final active = s.repo.activeMsByDay(fromDay: today - 13);
    final days = [
      for (var d = today - 13; d <= today; d++)
        DayCount(
          d,
          log.byDay[d]?.$1 ?? 0,
          log.byDay[d]?.$2 ?? 0,
          active[d] ?? 0,
        ),
    ];
    final active7 = days.skip(7).fold(0, (a, d) => a + d.activeMs);

    final forecast = List.filled(7, 0);
    final cards = s.repo.cards(deck: s.deck).values;
    var leeches = 0;
    for (final c in cards) {
      if (c.isLeech && !c.suspended) leeches++;
      final due = c.state.due;
      if (c.suspended || c.state.isNew || due == null) continue;
      final d = s.studyDay(due) - today;
      forecast[d < 0 ? 0 : d.clamp(0, 6)] += d > 6 ? 0 : 1;
    }

    return StatsData(
      levels: levels,
      expectedKnown: levels.fold(0.0, (a, l) => a + l.expectedKnown),
      itemsStarted: levels.fold(0, (a, l) => a + l.started),
      masteredItems: levels.fold(0, (a, l) => a + l.mastered),
      trueRetention30: log.trueRetention30,
      retentionSample30: log.retentionSample30,
      targetRetention:
          (s.deck == grammarDeck ? s.config.grammar : s.config.vocab)
              .desiredRetention,
      last14Days: days,
      activeMsTotal7: active7,
      forecast7: forecast,
      calibration: log.calibration,
      calibrationSample: log.calibration.fold(0, (a, b) => a + b.count),
      logLoss: log.logLoss,
      leeches: leeches,
      totalReviews: log.totalReviews,
    );
  }
}
