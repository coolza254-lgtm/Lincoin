import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/params_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/services/model_trainer.dart';
import 'package:lincoin_core/lincoin_core.dart';

/// Writes review_log rows for [cards] simulated cards of a learner who
/// forgets faster than the population model predicts.
void seedHistory(UserDb db, int cards) {
  final truth = List<double>.of(SrsConfig().parameters);
  for (var i = 0; i < 4; i++) {
    truth[i] /= 3;
  }
  truth[8] -= 0.5; // memories also grow more slowly after each recall
  final real = FsrsModel(truth);
  final sched = FsrsModel(List.of(SrsConfig().parameters));
  final rnd = math.Random(5);
  final start = DateTime.utc(2026, 1, 1, 9);
  var n = 0;
  void log(String card, Rating r, DateTime at) => db.db.execute(
    'INSERT INTO review_log(id, card_id, deck, ts_utc, tz_offset_min, '
    'study_day, question_type, is_correct, used_hint, marked_guess, gave_up, '
    'response_ms, rating, status_before, elapsed_days, params_version, '
    'algo_version) VALUES (?, ?, ?, ?, 0, 0, ?, 1, 0, 0, 0, 3000, ?, ?, 0, 0, 1)',
    [
      'r${n++}',
      card,
      'vocab',
      at.millisecondsSinceEpoch,
      'recog.flash',
      r.value,
      'review',
    ],
  );
  for (var c = 0; c < cards; c++) {
    var t = start.add(Duration(days: c % 40));
    final h = [ReviewEvent(Rating.good, t)];
    log('w:$c#recog', Rating.good, t);
    var s = real.initialStability(Rating.good);
    var d = real.initialDifficulty(Rating.good);
    for (var k = 0; k < 6; k++) {
      final ivl = sched.interval(sched.memoryState(h)!.$1, 0.9);
      t = t.add(Duration(days: ivl));
      final p = real.retrievability(ivl, s);
      final r = rnd.nextDouble() < p ? Rating.good : Rating.again;
      h.add(ReviewEvent(r, t));
      log('w:$c#recog', r, t);
      s = real.nextStability(d, s, p, r);
      d = real.nextDifficulty(d, r);
    }
  }
}

void main() {
  late UserDb db;
  late ModelTrainer trainer;
  setUp(() {
    db = UserDb.memory();
    trainer = ModelTrainer(ParamsRepo(db));
  });

  test('too little history: nothing to fit', () async {
    seedHistory(db, 5);
    expect(trainer.due(), isFalse);
    expect(await trainer.train(inIsolate: false), isNull);
    expect(ParamsRepo(db).active('vocab'), isNull);
  });

  test('fits personal parameters, keeps them, waits for new data', () async {
    seedHistory(db, 300);
    expect(trainer.due(), isTrue);
    final r = (await trainer.train(inIsolate: false))!;
    expect(r.active, isTrue);
    expect(r.rmseAfter, lessThan(r.rmseBefore));
    expect(r.version, 1);
    final active = ParamsRepo(db).active('vocab')!;
    expect(active.weights, r.weights);
    expect(active.reviews, greaterThanOrEqualTo(FsrsOptimizer.minReviews));
    // No new answers since: not due again.
    expect(trainer.due(), isFalse);
    // The scheduler accepts the fitted parameters.
    SrsScheduler(SrsConfig(parameters: active.weights, paramsVersion: 1));
  });
}
