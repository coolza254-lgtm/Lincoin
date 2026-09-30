import 'dart:math';

import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  test('3-year simulation: retention tracks the target, workload stays bounded',
      () {
    final r = simulateWorkload(
        config: SrsConfig(desiredRetention: 0.9), days: 3 * 365, newPerDay: 10);
    printOnFailure(
        'retention=${r.retention} max=${r.dailyReviews.reduce(max)}');
    expect(r.retention, closeTo(0.9, 0.03));
    expect(r.dailyReviews.reduce(max), lessThan(250));
    expect(r.dailyNew.reduce((a, b) => a + b), 10950);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('higher desired retention costs more reviews and retains more', () {
    SimulationResult run(double dr) => simulateWorkload(
        config: SrsConfig(desiredRetention: dr), days: 180, newPerDay: 10);
    final lo = run(0.85);
    final hi = run(0.95);
    expect(hi.totalAnswers, greaterThan(lo.totalAnswers));
    expect(hi.retention, greaterThan(lo.retention));
  });

  test('deck exhaustion stops new cards', () {
    final r = simulateWorkload(
        config: SrsConfig(), days: 30, newPerDay: 10, totalNewCards: 55);
    expect(r.dailyNew.reduce((a, b) => a + b), 55);
    expect(r.dailyNew.last, 0);
  });

  test('simulation is deterministic for a seed', () {
    SimulationResult run() =>
        simulateWorkload(config: SrsConfig(), days: 60, newPerDay: 5, seed: 3);
    expect(run().dailyReviews, run().dailyReviews);
  });
}
