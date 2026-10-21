import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as fsrs;

import '../util/hash.dart';
import 'card_state.dart';

/// One answer in a card's history (oldest first), as the optimizer needs it.
class ReviewEvent {
  final Rating rating;
  final DateTime atUtc;
  const ReviewEvent(this.rating, this.atUtc);
}

/// The FSRS-6 memory model with explicit parameters, written to match
/// package:fsrs 2.0.1 formula for formula (same clamps, same whole-day
/// elapsed time), so parameters fitted here schedule identically there.
class FsrsModel {
  final List<double> w;
  late final double decay = -w[20];
  late final double factor = math.pow(0.9, 1 / decay) - 1;

  FsrsModel(this.w);

  static double _clampS(double s) => math.max(s, fsrs.stabilityMin);
  static double _clampD(double d) =>
      d.clamp(fsrs.minDifficulty, fsrs.maxDifficulty);

  double retrievability(int elapsedDays, double s) =>
      math.pow(1 + factor * elapsedDays / s, decay).toDouble();

  double initialStability(Rating r) => _clampS(w[r.value - 1]);

  double initialDifficulty(Rating r) =>
      _clampD(w[4] - math.exp(w[5] * (r.value - 1)) + 1);

  double nextDifficulty(double d, Rating r) {
    final delta = -(w[6] * (r.value - 3));
    final damped = d + (10.0 - d) * delta / 9.0;
    final easy = initialDifficulty(Rating.easy);
    return _clampD(w[7] * easy + (1 - w[7]) * damped);
  }

  double shortTermStability(double s, Rating r) {
    var inc = math.exp(w[17] * (r.value - 3 + w[18])) * math.pow(s, -w[19]);
    if (r == Rating.good || r == Rating.easy) inc = math.max(inc, 1.0);
    return _clampS(s * inc);
  }

  double nextStability(double d, double s, double r, Rating rating) {
    final double next;
    if (rating == Rating.again) {
      final long = w[11] *
          math.pow(d, -w[12]) *
          (math.pow(s + 1, w[13]) - 1) *
          math.exp((1 - r) * w[14]);
      final short = s / math.exp(w[17] * w[18]);
      next = math.min(long, short);
    } else {
      final hard = rating == Rating.hard ? w[15] : 1.0;
      final easy = rating == Rating.easy ? w[16] : 1.0;
      next = s *
          (1 +
              math.exp(w[8]) *
                  (11 - d) *
                  math.pow(s, -w[9]) *
                  (math.exp((1 - r) * w[10]) - 1) *
                  hard *
                  easy);
    }
    return _clampS(next);
  }

  /// Interval in whole days for [retention], as package:fsrs computes it.
  int interval(double s, double retention, {int maxDays = 36500}) {
    final i = (s / factor) * (math.pow(retention, 1 / decay) - 1);
    return i.round().clamp(1, maxDays);
  }

  /// Stability and difficulty after [history]; null when it is empty.
  (double, double)? memoryState(List<ReviewEvent> history) {
    double? s;
    double? d;
    DateTime? last;
    for (final e in history) {
      if (s == null || d == null || last == null) {
        s = initialStability(e.rating);
        d = initialDifficulty(e.rating);
      } else {
        final days = e.atUtc.difference(last).inDays;
        s = days < 1
            ? shortTermStability(s, e.rating)
            : nextStability(d, s, retrievability(days, s), e.rating);
        d = nextDifficulty(d, e.rating);
      }
      last = e.atUtc;
    }
    return s == null ? null : (s, d!);
  }

  /// Walks a card's history; calls [onPredict] with the predicted recall
  /// and the outcome for every answer given a day or more after the
  /// previous one (same-day answers are learning steps, not memory tests).
  void replay(
    List<ReviewEvent> history,
    void Function(double predicted, bool recalled) onPredict,
  ) {
    double? s;
    double? d;
    DateTime? last;
    for (final e in history) {
      if (s == null || d == null || last == null) {
        s = initialStability(e.rating);
        d = initialDifficulty(e.rating);
      } else {
        final days = e.atUtc.difference(last).inDays;
        if (days < 1) {
          s = shortTermStability(s, e.rating);
        } else {
          final r = retrievability(days, s);
          onPredict(r, e.rating != Rating.again);
          s = nextStability(d, s, r, e.rating);
        }
        d = nextDifficulty(d, e.rating);
      }
      last = e.atUtc;
    }
  }
}

class OptimizerResult {
  final List<double> parameters;

  /// Mean log loss on the held-out cards with the starting parameters and
  /// with the fitted ones (lower is better).
  final double lossBefore;
  final double lossAfter;

  /// Calibration error (RMSE over predicted-recall bins), before / after.
  final double rmseBefore;
  final double rmseAfter;

  /// Memory tests (answers a day or more apart) the fit used.
  final int reviews;

  const OptimizerResult({
    required this.parameters,
    required this.lossBefore,
    required this.lossAfter,
    required this.rmseBefore,
    required this.rmseAfter,
    required this.reviews,
  });

  /// The fitted parameters predict the learner's recall better.
  bool get improved => lossAfter < lossBefore;
}

/// Fits FSRS-6 parameters to one learner's review history: minimises the
/// log loss of predicted recall on every memory test, with a pull toward
/// the starting (population) parameters that weakens as data grows, so a
/// small history cannot push the model somewhere strange. Cards are split
/// 80/20 by id; the result reports held-out loss so the caller can keep
/// the old parameters when the fit does not generalise.
class FsrsOptimizer {
  /// Fewer memory tests than this and the defaults are kept.
  static const minReviews = 150;

  static double logLoss(List<double> w, Iterable<List<ReviewEvent>> cards) {
    final m = FsrsModel(w);
    var sum = 0.0;
    var n = 0;
    for (final h in cards) {
      m.replay(h, (p, y) {
        final q = p.clamp(1e-6, 1 - 1e-6);
        sum += y ? -math.log(q) : -math.log(1 - q);
        n++;
      });
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Calibration RMSE: predictions binned into 20 bands, weighted by size.
  static double rmse(List<double> w, Iterable<List<ReviewEvent>> cards) {
    final m = FsrsModel(w);
    final count = List.filled(20, 0);
    final pred = List.filled(20, 0.0);
    final real = List.filled(20, 0.0);
    for (final h in cards) {
      m.replay(h, (p, y) {
        final i = math.min((p * 20).floor(), 19);
        count[i]++;
        pred[i] += p;
        real[i] += y ? 1 : 0;
      });
    }
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i < 20; i++) {
      if (count[i] == 0) continue;
      final diff = (pred[i] - real[i]) / count[i];
      sum += diff * diff * count[i];
      n += count[i];
    }
    return n == 0 ? 0 : math.sqrt(sum / n);
  }

  /// Memory tests in [cards] (answers a day or more after the previous).
  static int memoryTests(Iterable<List<ReviewEvent>> cards) {
    final m = FsrsModel(List.of(fsrs.defaultParameters));
    var n = 0;
    for (final h in cards) {
      m.replay(h, (p, y) => n++);
    }
    return n;
  }

  /// Returns null when there is too little history. [cards] maps a card id
  /// to its answers, oldest first.
  static OptimizerResult? fit(
    Map<String, List<ReviewEvent>> cards, {
    List<double> start = fsrs.defaultParameters,
    int iterations = 120,
  }) {
    final train = <List<ReviewEvent>>[];
    final test = <List<ReviewEvent>>[];
    for (final e in cards.entries) {
      if (e.value.length < 2) continue;
      (unitFromKey('split:${e.key}') < 0.8 ? train : test).add(e.value);
    }
    final total = memoryTests([...train, ...test]);
    if (total < minReviews || memoryTests(test) == 0) return null;
    final n = memoryTests(train);

    final w0 = List<double>.of(start);
    final lo = fsrs.lowerBoundsParameters;
    final hi = fsrs.upperBoundsParameters;
    // Scale of each parameter for the step size and the prior: its own size
    // (so a value near 0.2 is not moved in steps of 1), within limits.
    final scale = [
      for (var i = 0; i < w0.length; i++)
        math.min(math.max(w0[i].abs(), 0.05), (hi[i] - lo[i]) / 10),
    ];
    // Prior strength: equal to ~64 memory tests' worth of evidence.
    final lambda = 64.0 / n;

    double objective(List<double> w) {
      var prior = 0.0;
      for (var i = 0; i < w.length; i++) {
        final z = (w[i] - w0[i]) / scale[i];
        prior += z * z;
      }
      return logLoss(w, train) + lambda * prior / w.length;
    }

    // Adam on finite-difference gradients, in units of each parameter's
    // scale, clamped to the bounds package:fsrs accepts.
    var w = List<double>.of(w0);
    final m = List.filled(w.length, 0.0);
    final v = List.filled(w.length, 0.0);
    const lr0 = 0.04, b1 = 0.9, b2 = 0.999, eps = 1e-8, h = 1e-4;
    var best = w;
    var bestF = objective(w);
    for (var t = 1; t <= iterations; t++) {
      final f = objective(w);
      if (f < bestF) {
        bestF = f;
        best = List.of(w);
      }
      final g = List.filled(w.length, 0.0);
      for (var i = 0; i < w.length; i++) {
        final x = List<double>.of(w);
        x[i] = (x[i] + h * scale[i]).clamp(lo[i], hi[i]);
        final dx = (x[i] - w[i]) / scale[i];
        if (dx == 0) continue;
        g[i] = (objective(x) - f) / dx;
      }
      // Cosine-decayed learning rate: big moves first, fine-tuning last.
      final lr = lr0 * 0.5 * (1 + math.cos(math.pi * t / iterations));
      final next = List<double>.of(w);
      for (var i = 0; i < w.length; i++) {
        m[i] = b1 * m[i] + (1 - b1) * g[i];
        v[i] = b2 * v[i] + (1 - b2) * g[i] * g[i];
        final mh = m[i] / (1 - math.pow(b1, t));
        final vh = v[i] / (1 - math.pow(b2, t));
        next[i] = (w[i] - lr * scale[i] * mh / (math.sqrt(vh) + eps))
            .clamp(lo[i], hi[i]);
      }
      w = next;
    }
    if (objective(w) < bestF) best = w;

    return OptimizerResult(
      parameters: List.unmodifiable(best),
      lossBefore: logLoss(w0, test),
      lossAfter: logLoss(best, test),
      rmseBefore: rmse(w0, test),
      rmseAfter: rmse(best, test),
      reviews: total,
    );
  }
}

/// Knowledge kept per minute of study at one desired retention.
class RetentionPoint {
  final double retention;

  /// Expected words remembered at the horizon per hour of study.
  final double efficiency;

  /// Average study minutes per day the schedule asks for.
  final double minutesPerDay;
  const RetentionPoint(this.retention, this.efficiency, this.minutesPerDay);
}

/// Picks the desired retention that keeps the most words in memory per
/// minute spent (the idea behind FSRS's "minimum recommended retention"):
/// higher targets mean many more reviews, lower ones more forgetting and
/// costly relearning. Each simulated card follows the model's own
/// prediction with the learner's parameters; costs are seconds per answer.
class RetentionAdvisor {
  static List<RetentionPoint> curve({
    required List<double> parameters,
    int newPerDay = 10,
    int horizonDays = 365,
    int cards = 400,
    double secondsNew = 25,
    double secondsPass = 8,
    double secondsFail = 22,
    int seed = 7,
  }) {
    final model = FsrsModel(parameters);
    final out = <RetentionPoint>[];
    for (var r = 0.80; r <= 0.9501; r += 0.01) {
      final rnd = math.Random(seed);
      var seconds = 0.0;
      var known = 0.0;
      for (var c = 0; c < cards; c++) {
        // Cards start evenly through the horizon, as new cards would.
        final startDay = (c * horizonDays / cards).floor();
        var s = model.initialStability(Rating.good);
        var d = model.initialDifficulty(Rating.good);
        var day = startDay;
        seconds += secondsNew;
        while (true) {
          final ivl = model.interval(s, r);
          if (day + ivl > horizonDays) {
            known += model.retrievability(horizonDays - day, s);
            break;
          }
          day += ivl;
          final p = model.retrievability(ivl, s);
          if (rnd.nextDouble() < p) {
            seconds += secondsPass;
            s = model.nextStability(d, s, p, Rating.good);
            d = model.nextDifficulty(d, Rating.good);
          } else {
            seconds += secondsFail;
            s = model.nextStability(d, s, p, Rating.again);
            d = model.nextDifficulty(d, Rating.again);
            // One relearning step, passed the same day.
            s = model.shortTermStability(s, Rating.good);
          }
        }
      }
      final scale = newPerDay * horizonDays / cards;
      out.add(
        RetentionPoint(
          double.parse(r.toStringAsFixed(2)),
          known / (seconds / 3600),
          seconds * scale / 60 / horizonDays,
        ),
      );
    }
    return out;
  }

  /// The retention with the best [RetentionPoint.efficiency]; among
  /// near-ties (within 1%) the higher retention, since remembering more is
  /// worth a little time.
  static double recommend(List<RetentionPoint> curve) {
    final best = curve.map((p) => p.efficiency).reduce(math.max);
    return curve
        .where((p) => p.efficiency >= best * 0.99)
        .map((p) => p.retention)
        .reduce(math.max);
  }
}
