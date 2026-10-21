import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

/// Review histories of a simulated learner whose memory follows [truth]:
/// each card is reviewed when the schedule (default parameters, 90%) says,
/// and recalled with the probability the true model gives.
Map<String, List<ReviewEvent>> simulate(List<double> truth, {int cards = 400}) {
  final rnd = math.Random(3);
  final real = FsrsModel(truth);
  final sched = FsrsModel(List.of(fsrs.defaultParameters));
  final start = DateTime.utc(2025, 1, 1, 9);
  final out = <String, List<ReviewEvent>>{};
  for (var c = 0; c < cards; c++) {
    final first = start.add(Duration(days: c % 60));
    final h = [ReviewEvent(Rating.good, first)];
    var sTrue = real.initialStability(Rating.good);
    var dTrue = real.initialDifficulty(Rating.good);
    var t = first;
    for (var k = 0; k < 8; k++) {
      final (sSched, _) = sched.memoryState(h)!;
      final ivl = sched.interval(sSched, 0.9);
      t = t.add(Duration(days: ivl));
      final p = real.retrievability(ivl, sTrue);
      final ok = rnd.nextDouble() < p;
      final rating = ok ? Rating.good : Rating.again;
      h.add(ReviewEvent(rating, t));
      sTrue = real.nextStability(dTrue, sTrue, p, rating);
      dTrue = real.nextDifficulty(dTrue, rating);
    }
    out['c$c'] = h;
  }
  return out;
}

void main() {
  test('FsrsModel follows package:fsrs exactly', () {
    final s = SrsScheduler(SrsConfig(enableFuzz: false));
    final m = FsrsModel(List.of(fsrs.defaultParameters));
    var state = CardState.initial;
    final t0 = DateTime.utc(2025, 3, 1, 8);
    final history = <ReviewEvent>[];
    for (final (minutes, r) in [
      (0, Rating.good),
      (10, Rating.good),
      (60 * 24 * 3, Rating.hard),
      (60 * 24 * 10, Rating.again),
      (60 * 24 * 10 + 15, Rating.good),
      (60 * 24 * 30, Rating.easy),
    ]) {
      final at = t0.add(Duration(minutes: minutes));
      state = s.review(cardId: 'x', state: state, rating: r, nowUtc: at).after;
      history.add(ReviewEvent(r, at));
      final (ms, md) = m.memoryState(history)!;
      expect(ms, closeTo(state.stability!, 1e-9));
      expect(md, closeTo(state.difficulty!, 1e-9));
    }
  });

  test('too little history keeps the defaults', () {
    final few = simulate(List.of(fsrs.defaultParameters), cards: 10);
    expect(FsrsOptimizer.fit(few), isNull);
  });

  test('fits a learner who forgets faster than average', () {
    // This learner's memories are weaker: initial stability a third of the
    // population's and slower growth after each recall.
    final truth = List<double>.of(fsrs.defaultParameters);
    for (var i = 0; i < 4; i++) {
      truth[i] /= 3;
    }
    truth[8] -= 0.5;
    final r = FsrsOptimizer.fit(simulate(truth), iterations: 80)!;
    expect(r.improved, isTrue);
    // Predictions match this learner's real recall much more closely.
    expect(r.rmseAfter, lessThan(r.rmseBefore * 0.6));
    // Moves toward the truth on first-review stability.
    expect(r.parameters[2], lessThan(fsrs.defaultParameters[2]));
    for (var i = 0; i < r.parameters.length; i++) {
      expect(
          r.parameters[i],
          inInclusiveRange(
            fsrs.lowerBoundsParameters[i],
            fsrs.upperBoundsParameters[i],
          ));
    }
    // The fitted parameters are accepted by package:fsrs.
    SrsScheduler(SrsConfig(parameters: r.parameters));
  });

  test('retention advisor: a sensible target and a cost curve', () {
    final curve = RetentionAdvisor.curve(
      parameters: List.of(fsrs.defaultParameters),
    );
    expect(curve.first.retention, 0.80);
    expect(curve.last.retention, 0.95);
    // Higher targets cost more time per day.
    expect(curve.last.minutesPerDay, greaterThan(curve.first.minutesPerDay));
    final r = RetentionAdvisor.recommend(curve);
    expect(r, inInclusiveRange(0.80, 0.95));
  });
}
