import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/services/stats_service.dart';
import 'package:lincoin/services/study_service.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../support/fixture.dart';

void main() {
  test('SQL review summary matches the Metrics rules', () {
    final db = UserDb.memory();
    final catalog = fixtureCatalog();
    var now = DateTime.utc(2026, 9, 1, 3);
    final rnd = math.Random(7);
    StudyService svc() => StudyService(
      db: db,
      catalog: catalog,
      settings: const AppSettings(),
      clock: Clock(() => now, () => 420),
    );
    // Two months of daily sessions with ~80 % correct answers.
    for (var day = 0; day < 60; day++) {
      final s = svc();
      final queue = SessionQueue(initial: s.sessionOrder(s.plan()));
      for (var guard = 0; guard < 100; guard++) {
        final id = queue.next(now);
        if (id == null) break;
        final q = s.question(id);
        if (q.needsIntro) {
          s.introduce(q);
          queue.afterIntro(q.cardId, now);
          continue;
        }
        final r = s.answer(
          q,
          AnswerEvent(
            isCorrect: rnd.nextDouble() < 0.8,
            responseMs: 2000 + rnd.nextInt(6000),
          ),
        );
        if (r.outcome.after.inSteps) {
          queue.requeue(q.cardId, r.outcome.after.due!);
        }
        now = now.add(const Duration(minutes: 1));
      }
      now = DateTime.utc(2026, 9, 1, 3).add(Duration(days: day + 1));
    }

    final s = svc();
    final repo = StudyRepo(db);
    final today = s.studyDay();
    final log = repo.reviewRecords(deck: vocabDeck);
    expect(log.where((r) => r.statusBefore == CardStatus.review), isNotEmpty);
    final metrics = Metrics(s.scheduler, s.config.mastery);
    final sum = repo.reviewSummary(
      deck: vocabDeck,
      fromDay14: today - 13,
      fromDay30: today - 29,
    );

    expect(sum.totalReviews, log.length);
    expect(
      sum.trueRetention30,
      closeTo(metrics.trueRetention(log, fromDay: today - 29)!, 1e-12),
    );
    expect(
      sum.retentionSample30,
      log
          .where(
            (r) =>
                r.statusBefore == CardStatus.review && r.studyDay >= today - 29,
          )
          .length,
    );
    for (var d = today - 13; d <= today; d++) {
      final rows = log.where((r) => r.studyDay == d);
      expect(sum.byDay[d]?.$1 ?? 0, rows.length, reason: 'day $d');
      expect(sum.byDay[d]?.$2 ?? 0, rows.where((r) => r.rating.isPass).length);
    }
    final cal = metrics.calibration(log, binWidth: 0.1);
    expect(sum.calibration, hasLength(cal.length));
    for (final (i, b) in cal.indexed) {
      final got = sum.calibration[i];
      expect(got.lower, closeTo(b.lower, 1e-12));
      expect(got.count, b.count);
      expect(got.meanPredicted, closeTo(b.meanPredicted, 1e-9));
      expect(got.actual, closeTo(b.actual, 1e-12));
    }
    expect(sum.logLoss, closeTo(metrics.logLoss(log)!, 1e-9));

    final stats = StatsService(s).compute();
    expect(stats.totalReviews, log.length);
    expect(stats.last14Days, hasLength(14));
  });

  test('cards() is read once until the next write', () {
    final db = UserDb.memory();
    final catalog = fixtureCatalog();
    final s = StudyService(
      db: db,
      catalog: catalog,
      settings: const AppSettings(),
      clock: Clock(() => DateTime.utc(2026, 10, 1, 3), () => 420),
    );
    final repo = StudyRepo(db);
    final a = repo.cards(deck: vocabDeck);
    expect(identical(a, repo.cards(deck: vocabDeck)), isTrue);
    s.introduce(s.question(s.plan().queue.newCards.first.cardId));
    final b = repo.cards(deck: vocabDeck);
    expect(identical(a, b), isFalse);
    expect(b, hasLength(a.length + 1));
  });
}
