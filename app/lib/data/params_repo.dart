import 'dart:convert';

import 'package:lincoin_core/lincoin_core.dart';

import 'user_db.dart';

/// One fit of the memory model to the learner's history.
class FittedParams {
  final int version;
  final List<double> weights;
  final DateTime createdAt;
  final double lossBefore;
  final double lossAfter;
  final double rmseBefore;
  final double rmseAfter;

  /// Memory tests (answers a day or more apart) the fit used.
  final int reviews;

  /// In use for scheduling (the fit beat the previous parameters).
  final bool active;

  const FittedParams({
    required this.version,
    required this.weights,
    required this.createdAt,
    required this.lossBefore,
    required this.lossAfter,
    required this.rmseBefore,
    required this.rmseAfter,
    required this.reviews,
    required this.active,
  });
}

/// FSRS parameters fitted to this learner (table fsrs_params). Every fit is
/// kept; only one per deck is active. weights_json holds the weights and
/// the fit's figures.
class ParamsRepo {
  final UserDb u;
  ParamsRepo(this.u);

  FittedParams _row(Map<String, Object?> r) {
    final j = jsonDecode(r['weights_json'] as String) as Map<String, Object?>;
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return FittedParams(
      version: r['version'] as int,
      weights: [for (final x in j['w'] as List<Object?>) (x as num).toDouble()],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        r['created_at'] as int,
        isUtc: true,
      ),
      lossBefore: (r['log_loss_before'] as num?)?.toDouble() ?? 0,
      lossAfter: (r['log_loss_after'] as num?)?.toDouble() ?? 0,
      rmseBefore: n('rmseBefore'),
      rmseAfter: n('rmseAfter'),
      reviews: (j['reviews'] as num?)?.toInt() ?? 0,
      active: (r['is_active'] as int) == 1,
    );
  }

  List<FittedParams> _select(String where, List<Object?> args) => [
    for (final r in u.db.select(
      'SELECT version, weights_json, created_at, log_loss_before, '
      'log_loss_after, is_active FROM fsrs_params WHERE $where',
      args,
    ))
      _row({for (final c in r.keys) c: r[c]}),
  ];

  FittedParams? active(String deck) => _select(
    'deck = ? AND is_active = 1 ORDER BY version DESC LIMIT 1',
    [deck],
  ).firstOrNull;

  /// The most recent fit, kept or not.
  FittedParams? latest(String deck) =>
      _select('deck = ? ORDER BY version DESC LIMIT 1', [deck]).firstOrNull;

  /// Stores a fit; makes it active when [OptimizerResult.improved].
  FittedParams save(String deck, OptimizerResult r, DateTime now) {
    final version =
        (u.db.select(
                  'SELECT MAX(version) AS v FROM fsrs_params WHERE deck = ?',
                  [deck],
                ).first['v']
                as int? ??
            0) +
        1;
    u.tx(() {
      if (r.improved) {
        u.db.execute('UPDATE fsrs_params SET is_active = 0 WHERE deck = ?', [
          deck,
        ]);
      }
      u.db.execute(
        'INSERT INTO fsrs_params(id, deck, version, weights_json, created_at, '
        'log_loss_before, log_loss_after, is_active) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          UserDb.newId(),
          deck,
          version,
          jsonEncode({
            'w': r.parameters,
            'reviews': r.reviews,
            'rmseBefore': r.rmseBefore,
            'rmseAfter': r.rmseAfter,
          }),
          now.millisecondsSinceEpoch,
          r.lossBefore,
          r.lossAfter,
          r.improved ? 1 : 0,
        ],
      );
    });
    return latest(deck)!;
  }

  /// Every card's answers, oldest first (input for the optimizer).
  Map<String, List<ReviewEvent>> histories(String deck) {
    final out = <String, List<ReviewEvent>>{};
    for (final r in u.db.select(
      'SELECT card_id, rating, ts_utc FROM review_log WHERE deck = ? '
      'ORDER BY card_id, ts_utc',
      [deck],
    )) {
      out
          .putIfAbsent(r.columnAt(0) as String, () => [])
          .add(
            ReviewEvent(
              Rating.fromValue(r.columnAt(1) as int),
              DateTime.fromMillisecondsSinceEpoch(
                r.columnAt(2) as int,
                isUtc: true,
              ),
            ),
          );
    }
    return out;
  }
}
