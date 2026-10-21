import 'dart:isolate';

import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/params_repo.dart';

/// Fits the memory model to the learner's own answers (FsrsOptimizer) and
/// keeps the result when it predicts their recall better.
class ModelTrainer {
  final ParamsRepo repo;
  ModelTrainer(this.repo);

  /// Refit once this many new memory tests have arrived since the last fit.
  static const refitEvery = 100;

  /// Memory tests in the history and in the last fit.
  ({int now, int atLastFit}) progress([String deck = vocabDeck]) => (
    now: FsrsOptimizer.memoryTests(repo.histories(deck).values),
    atLastFit: repo.latest(deck)?.reviews ?? 0,
  );

  /// Whether enough new answers have arrived to fit again.
  bool due([String deck = vocabDeck]) {
    final p = progress(deck);
    return p.now >= FsrsOptimizer.minReviews &&
        p.now - p.atLastFit >= (p.atLastFit == 0 ? 0 : refitEvery);
  }

  /// Fits now (in a background isolate unless [inIsolate] is false) and
  /// stores the result. Null when there is too little history.
  Future<FittedParams?> train({
    String deck = vocabDeck,
    bool inIsolate = true,
    DateTime? now,
  }) async {
    final data = repo.histories(deck);
    final start = repo.active(deck)?.weights;
    OptimizerResult? fit() => start == null
        ? FsrsOptimizer.fit(data)
        : FsrsOptimizer.fit(data, start: start);
    final r = inIsolate ? await Isolate.run(fit) : fit();
    if (r == null) return null;
    return repo.save(deck, r, now ?? DateTime.now().toUtc());
  }

  /// Fits when [due]; for app start-up.
  Future<FittedParams?> maybeTrain() async => due() ? train() : null;
}
