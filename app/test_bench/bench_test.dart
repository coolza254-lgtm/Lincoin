// Performance benchmark on real content and a simulated long-term learner.
// Not part of CI: flutter test test_bench/bench_test.dart
// BENCH_CONTENT=<path to content.db> BENCH_DAYS=<simulated days>
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/content_db.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/services/challenge_service.dart';
import 'package:lincoin/services/practice_service.dart';
import 'package:lincoin/services/stats_service.dart';
import 'package:lincoin/services/study_service.dart';
import 'package:lincoin_core/lincoin_core.dart';

T timed<T>(String label, T Function() f, {int runs = 5}) {
  late T r;
  final sw = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    r = f();
  }
  sw.stop();
  // ignore: avoid_print
  print(
    '${label.padRight(28)} ${(sw.elapsedMicroseconds / runs / 1000).toStringAsFixed(2)} ms',
  );
  return r;
}

void main() {
  test('bench', () {
    final path = Platform.environment['BENCH_CONTENT']!;
    final days = int.parse(Platform.environment['BENCH_DAYS'] ?? '120');
    final content = ContentDb.openFile(path);
    final catalog = timed('Catalog.load', () => Catalog.load(content), runs: 3);
    // ignore: avoid_print
    print('path items: ${catalog.path.length}');
    final db = UserDb.memory();
    var now = DateTime.utc(2026, 1, 1, 3);
    const settings = AppSettings(vocabNewPerDay: 20, grammarNewPerDay: 3);
    final rnd = math.Random(1);
    StudyService svc(String deck) => StudyService(
      db: db,
      catalog: catalog,
      settings: settings,
      clock: Clock(() => now, () => 420),
      deck: deck,
    );
    final sim = Stopwatch()..start();
    var answers = 0;
    for (var d = 0; d < days; d++) {
      for (final deck in [vocabDeck, grammarDeck]) {
        final s = svc(deck);
        final plan = s.plan();
        final queue = SessionQueue(initial: s.sessionOrder(plan));
        var guard = 0;
        while (guard++ < 400) {
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
              isCorrect: rnd.nextDouble() < 0.88,
              responseMs: 3000 + rnd.nextInt(5000),
            ),
          );
          answers++;
          if (r.outcome.after.inSteps) {
            queue.requeue(q.cardId, r.outcome.after.due!);
          }
          now = now.add(const Duration(seconds: 8));
        }
        s.finishSession(answeredAny: true);
      }
      now = DateTime.utc(2026, 1, 1, 3).add(Duration(days: d + 1));
    }
    // ignore: avoid_print
    print(
      'simulated $days days, $answers answers in ${sim.elapsed.inSeconds}s; '
      'cards=${db.db.select('SELECT count(*) FROM cards').first.columnAt(0)}',
    );
    final v = svc(vocabDeck);
    final g = svc(grammarDeck);
    timed('plan(vocab)', v.plan);
    timed('plan(grammar)', g.plan);
    timed('coverage(vocab)', v.coverage);
    timed('stats(vocab)', () => StatsService(v).compute(), runs: 3);
    timed('balance', () => LedgerRepo(db).balance());
    final p = PracticeService(v);
    timed('practice.pool', p.pool);
    timed('practice.todayPractice', p.todayPractice);
    final ch = ChallengeService(v);
    timed(
      'challenge.active+history',
      () => (ch.active(), ch.history(limit: 10)),
    );
    final firstReview = v.plan().queue.reviews.first.cardId;
    timed('question()', () => v.question(firstReview));
    final word = catalog.path.whereType<WordStudy>().first.id;
    timed('examplesFor', () => content.examplesFor(word));
    final day = v.studyDay();
    timed('repo.introducedOn', () => v.repo.introducedOn(day, vocabDeck));
    timed('repo.itemsReviewedOn', () => v.repo.itemsReviewedOn(day, vocabDeck));
    timed('trackedCards', v.trackedCards);
    timed('reviewRecords(all)', () => v.repo.reviewRecords(deck: vocabDeck));
    timed('checkTyped', () => v.checkTyped(v.question(firstReview), 'あいう'));
    final rv = db.db
        .select('SELECT count(*) FROM review_log')
        .first
        .columnAt(0);
    final pv = db.db
        .select('SELECT count(*) FROM practice_log')
        .first
        .columnAt(0);
    // ignore: avoid_print
    print('review_log=$rv practice_log=$pv');
    timed('StudyRepo.cards', () => StudyRepo(db).cards(deck: vocabDeck));
    timed('responseTimes', () => StudyRepo(db).responseTimes());
  }, timeout: const Timeout(Duration(minutes: 30)));
}
