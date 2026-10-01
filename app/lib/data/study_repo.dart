import 'dart:convert';
import 'dart:math' as math;

import 'package:lincoin_core/lincoin_core.dart';
import 'package:sqlite3/sqlite3.dart' show Row, SqliteException;

import 'user_db.dart';

/// A card row: scheduler state plus bookkeeping.
class StoredCard {
  final String id;
  final String itemId;
  final String deck;
  final Facet facet;
  final CardState state;
  final bool suspended;
  final bool isLeech;
  final int introducedDay;
  final DateTime? firstMasteredAt;

  const StoredCard({
    required this.id,
    required this.itemId,
    required this.deck,
    required this.facet,
    required this.state,
    required this.suspended,
    required this.isLeech,
    required this.introducedDay,
    required this.firstMasteredAt,
  });
}

/// Everything recorded for one graded answer, written in one transaction.
class ReviewRecordInput {
  final String logId;
  final String cardId;
  final String itemId;
  final String deck;
  final Facet facet;
  final String? sessionId;
  final DateTime tsUtc;
  final int tzOffsetMin;
  final int studyDay;
  final String questionType;
  final String? answerRaw;
  final AnswerEvent answer;
  final ReviewOutcome outcome;
  final Rating rating;
  final int paramsVersion;
  final bool isLeech;
  final bool firstMastered;

  const ReviewRecordInput({
    required this.logId,
    required this.cardId,
    required this.itemId,
    required this.deck,
    required this.facet,
    required this.sessionId,
    required this.tsUtc,
    required this.tzOffsetMin,
    required this.studyDay,
    required this.questionType,
    required this.answerRaw,
    required this.answer,
    required this.outcome,
    required this.rating,
    required this.paramsVersion,
    required this.isLeech,
    required this.firstMastered,
  });
}

/// Aggregated review-log numbers (see [StudyRepo.reviewSummary]).
class ReviewSummary {
  final int totalReviews;

  /// study day → (answers, passed) from the requested first day on.
  final Map<int, (int, int)> byDay;
  final int retentionSample30;
  final int retentionPassed30;
  final List<CalibrationBin> calibration;
  final double? logLoss;

  const ReviewSummary({
    required this.totalReviews,
    required this.byDay,
    required this.retentionSample30,
    required this.retentionPassed30,
    required this.calibration,
    required this.logLoss,
  });

  double? get trueRetention30 =>
      retentionSample30 == 0 ? null : retentionPassed30 / retentionSample30;
}

class StudyRepo {
  final UserDb u;
  StudyRepo(this.u);

  static int? _ms(DateTime? t) => t?.millisecondsSinceEpoch;
  static DateTime? _dt(Object? ms) => ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

  static const _cardColumns =
      'id, item_id, deck, facet, status, step_index, stability, difficulty, '
      'due_at, last_review_at, last_rating, reps, lapses, suspended, '
      'is_leech, introduced_day, first_mastered_at';

  static final _status = {for (final s in CardStatus.values) s.name: s};
  static final _facet = {for (final f in Facet.values) f.name: f};
  static final _rating = {for (final r in Rating.values) r.value: r};

  /// All cards (of [deck]), read once until the next write: the queue,
  /// coverage, stats and practice all start from this map. Read-only.
  Map<String, StoredCard> cards({String? deck}) =>
      u.memo('cards:${deck ?? '*'}', () {
        final rows = deck == null
            ? u.db.select('SELECT $_cardColumns FROM cards')
            : u.db.select('SELECT $_cardColumns FROM cards WHERE deck = ?', [
                deck,
              ]);
        return Map.unmodifiable({
          for (final r in rows) r.columnAt(0) as String: _card(r),
        });
      });

  StoredCard? card(String id) {
    final rows = u.db.select('SELECT $_cardColumns FROM cards WHERE id = ?', [
      id,
    ]);
    return rows.isEmpty ? null : _card(rows.first);
  }

  /// Columns in [_cardColumns] order (by index: this runs for every card).
  StoredCard _card(Row r) => StoredCard(
    id: r.columnAt(0) as String,
    itemId: r.columnAt(1) as String,
    deck: r.columnAt(2) as String,
    facet: _facet[r.columnAt(3)] ?? Facet.recog,
    state: CardState(
      status: _status[r.columnAt(4)]!,
      step: r.columnAt(5) as int?,
      stability: (r.columnAt(6) as num?)?.toDouble(),
      difficulty: (r.columnAt(7) as num?)?.toDouble(),
      due: _dt(r.columnAt(8)),
      lastReview: _dt(r.columnAt(9)),
      lastRating: _rating[r.columnAt(10)],
      reps: r.columnAt(11) as int,
      lapses: r.columnAt(12) as int,
    ),
    suspended: r.columnAt(13) == 1,
    isLeech: r.columnAt(14) == 1,
    introducedDay: r.columnAt(15) as int,
    firstMasteredAt: _dt(r.columnAt(16)),
  );

  /// Records that a new card was shown to the learner (introduction screen
  /// or first question). Counts toward today's new-card limit.
  void introduce({
    required String cardId,
    required String itemId,
    required String deck,
    required Facet facet,
    required DateTime nowUtc,
    required int studyDay,
  }) {
    u.db.execute(
      'INSERT OR IGNORE INTO cards(id, item_id, deck, facet, status, '
      'introduced_at, introduced_day, uuid, updated_at) '
      "VALUES (?, ?, ?, ?, 'newCard', ?, ?, ?, ?)",
      [
        cardId,
        itemId,
        deck,
        facet.name,
        _ms(nowUtc),
        studyDay,
        UserDb.newId(),
        _ms(nowUtc),
      ],
    );
  }

  int introducedOn(int studyDay, String deck) =>
      u.db
              .select(
                'SELECT count(*) FROM cards WHERE introduced_day = ? AND deck = ?',
                [studyDay, deck],
              )
              .first
              .columnAt(0)
          as int;

  /// Items whose cards were first introduced on [studyDay].
  List<String> introducedItemsOn(int studyDay, String deck) => [
    for (final r in u.db.select(
      'SELECT item_id FROM cards WHERE introduced_day = ? AND deck = ?',
      [studyDay, deck],
    ))
      r['item_id'] as String,
  ];

  Set<String> itemsReviewedOn(int studyDay, String deck) => {
    for (final r in u.db.select(
      'SELECT DISTINCT card_id FROM review_log '
      'WHERE study_day = ? AND deck = ?',
      [studyDay, deck],
    ))
      itemIdOf(r['card_id'] as String),
  };

  /// Writes the answer, the new card state and any Lincoin in one go.
  void recordReview(ReviewRecordInput e, List<LedgerEntry> coins) {
    final a = e.outcome.after;
    final b = e.outcome.before;
    u.tx(() {
      u.db.execute(
        'INSERT INTO review_log(id, card_id, deck, session_id, ts_utc, '
        'tz_offset_min, study_day, question_type, answer_raw, is_correct, '
        'used_hint, marked_guess, gave_up, response_ms, rating, '
        'status_before, elapsed_days, s_before, d_before, s_after, d_after, '
        'due_after, r_predicted, params_version, algo_version) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          e.logId,
          e.cardId,
          e.deck,
          e.sessionId,
          _ms(e.tsUtc),
          e.tzOffsetMin,
          e.studyDay,
          e.questionType,
          e.answerRaw,
          e.answer.isCorrect ? 1 : 0,
          e.answer.usedHint ? 1 : 0,
          e.answer.markedGuess ? 1 : 0,
          e.answer.gaveUp ? 1 : 0,
          e.answer.responseMs,
          e.rating.value,
          b.status.name,
          e.outcome.elapsedDays,
          b.stability,
          b.difficulty,
          a.stability,
          a.difficulty,
          _ms(a.due),
          e.outcome.retrievabilityBefore,
          e.paramsVersion,
          schedulerAlgoVersion,
        ],
      );
      // The row exists if the card was introduced; insert otherwise.
      u.db.execute(
        'INSERT OR IGNORE INTO cards(id, item_id, deck, facet, status, '
        'introduced_at, introduced_day, uuid, updated_at) '
        "VALUES (?, ?, ?, ?, 'newCard', ?, ?, ?, ?)",
        [
          e.cardId,
          e.itemId,
          e.deck,
          e.facet.name,
          _ms(e.tsUtc),
          e.studyDay,
          UserDb.newId(),
          _ms(e.tsUtc),
        ],
      );
      u.db.execute(
        'UPDATE cards SET status = ?, due_at = ?, stability = ?, '
        'difficulty = ?, step_index = ?, reps = ?, lapses = ?, '
        'last_review_at = ?, last_rating = ?, is_leech = ?, '
        'first_mastered_at = COALESCE(first_mastered_at, ?), '
        'updated_at = ? WHERE id = ?',
        [
          a.status.name,
          _ms(a.due),
          a.stability,
          a.difficulty,
          a.step,
          a.reps,
          a.lapses,
          _ms(a.lastReview),
          a.lastRating?.value,
          e.isLeech ? 1 : 0,
          e.firstMastered ? _ms(e.tsUtc) : null,
          _ms(e.tsUtc),
          e.cardId,
        ],
      );
      LedgerRepo(u).insertAll(coins);
    });
  }

  /// Review history for metrics (oldest first).
  List<ReviewRecord> reviewRecords({String? deck, int? fromDay}) {
    final where = <String>[];
    final args = <Object?>[];
    if (deck != null) {
      where.add('deck = ?');
      args.add(deck);
    }
    if (fromDay != null) {
      where.add('study_day >= ?');
      args.add(fromDay);
    }
    final sql =
        'SELECT card_id, deck, ts_utc, study_day, status_before, '
        'rating, r_predicted, response_ms FROM review_log'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'} '
        'ORDER BY ts_utc';
    return [
      for (final r in u.db.select(sql, args))
        ReviewRecord(
          cardId: r.columnAt(0) as String,
          deck: r.columnAt(1) as String,
          tsUtc: _dt(r.columnAt(2))!,
          studyDay: r.columnAt(3) as int,
          statusBefore: _status[r.columnAt(4)]!,
          rating: _rating[r.columnAt(5)]!,
          rPredicted: (r.columnAt(6) as num?)?.toDouble(),
          responseMs: r.columnAt(7) as int,
        ),
    ];
  }

  /// Review-log numbers for the stats screen, aggregated by SQLite so the
  /// cost stays small however long the log grows. Same rules as [Metrics]
  /// (trueRetention, calibration, logLoss); a test keeps them in step.
  ReviewSummary reviewSummary({
    required String deck,
    required int fromDay14,
    required int fromDay30,
    double binWidth = 0.1,
  }) {
    final db = u.db;
    final total =
        db
                .select('SELECT count(*) FROM review_log WHERE deck = ?', [
                  deck,
                ])
                .first
                .columnAt(0)
            as int;
    final byDay = <int, (int, int)>{
      for (final r in db.select(
        'SELECT study_day, count(*), SUM(rating <> 1) FROM review_log '
        'WHERE deck = ? AND study_day >= ? GROUP BY study_day',
        [deck, fromDay14],
      ))
        r.columnAt(0) as int: (r.columnAt(1) as int, r.columnAt(2) as int),
    };
    final ret = db.select(
      'SELECT count(*), COALESCE(SUM(rating <> 1), 0) FROM review_log '
      "WHERE deck = ? AND status_before = 'review' AND study_day >= ?",
      [deck, fromDay30],
    ).first;
    const reviewed =
        "deck = ? AND status_before = 'review' AND r_predicted IS NOT NULL";
    final bins = (1 / binWidth).round();
    final calibration = [
      for (final r in db.select(
        'SELECT MIN(CAST(r_predicted / ? AS INTEGER), ?) AS b, count(*), '
        'SUM(r_predicted), SUM(rating <> 1) FROM review_log '
        'WHERE $reviewed GROUP BY b ORDER BY b',
        [binWidth, bins - 1, deck],
      ))
        CalibrationBin(
          (r.columnAt(0) as int) * binWidth,
          ((r.columnAt(0) as int) + 1) * binWidth,
          r.columnAt(1) as int,
          (r.columnAt(2) as num).toDouble() / (r.columnAt(1) as int),
          (r.columnAt(3) as int) / (r.columnAt(1) as int),
        ),
    ];
    return ReviewSummary(
      totalReviews: total,
      byDay: byDay,
      retentionSample30: ret.columnAt(0) as int,
      retentionPassed30: ret.columnAt(1) as int,
      calibration: calibration,
      logLoss: _logLoss(reviewed, deck),
    );
  }

  double? _logLoss(String where, String deck) {
    const eps = 1e-6;
    try {
      final r = u.db.select(
        'SELECT SUM(CASE WHEN rating <> 1 THEN -ln(p) ELSE -ln(1 - p) END), '
        'count(*) FROM (SELECT rating, MAX(MIN(r_predicted, ${1 - eps}), '
        '$eps) AS p FROM review_log WHERE $where)',
        [deck],
      ).first;
      final n = r.columnAt(1) as int;
      return n == 0 ? null : (r.columnAt(0) as num).toDouble() / n;
    } on SqliteException {
      // SQLite built without math functions: sum in Dart instead.
      var n = 0;
      var sum = 0.0;
      for (final r in u.db.select(
        'SELECT rating, r_predicted FROM review_log WHERE $where',
        [deck],
      )) {
        final q = (r.columnAt(1) as num).toDouble().clamp(eps, 1 - eps);
        sum += r.columnAt(0) != 1 ? -math.log(q) : -math.log(1 - q);
        n++;
      }
      return n == 0 ? null : sum / n;
    }
  }

  ResponseTimeTracker responseTimes({int perType = 200}) {
    final t = ResponseTimeTracker(window: perType);
    // One indexed query per question type (idx_review_type_ts) instead of
    // ranking the whole log.
    final types = [
      for (final r in u.db.select(
        'SELECT DISTINCT question_type FROM review_log',
      ))
        r.columnAt(0) as String,
    ];
    for (final type in types) {
      final rows = u.db.select(
        'SELECT response_ms FROM review_log WHERE question_type = ? '
        'AND is_correct = 1 AND used_hint = 0 AND marked_guess = 0 '
        'AND gave_up = 0 ORDER BY ts_utc DESC LIMIT ?',
        [type, perType],
      );
      for (final r in rows.reversed) {
        t.add(
          type,
          AnswerEvent(isCorrect: true, responseMs: r.columnAt(0) as int),
        );
      }
    }
    return t;
  }

  // ---- sessions ----
  void startSession(
    String id,
    String mode,
    String deck,
    DateTime now,
    int studyDay,
  ) => u.db.execute(
    'INSERT INTO sessions(id, mode, deck, started_at, study_day) '
    'VALUES (?, ?, ?, ?, ?)',
    [id, mode, deck, _ms(now), studyDay],
  );

  void updateSession(
    String id, {
    required int activeMs,
    required int answered,
    DateTime? endedAt,
    Map<String, Object?>? summary,
  }) => u.db.execute(
    'UPDATE sessions SET active_ms = ?, answered = ?, '
    'ended_at = COALESCE(?, ended_at), '
    'summary_json = COALESCE(?, summary_json) WHERE id = ?',
    [
      activeMs,
      answered,
      _ms(endedAt),
      summary == null ? null : jsonEncode(summary),
      id,
    ],
  );

  /// Active study time per study day.
  Map<int, int> activeMsByDay({required int fromDay}) => {
    for (final r in u.db.select(
      'SELECT study_day, SUM(active_ms) AS ms FROM sessions '
      'WHERE study_day >= ? GROUP BY study_day',
      [fromDay],
    ))
      r['study_day'] as int: (r['ms'] as num).toInt(),
  };

  void reportContent(
    String itemId,
    String kind,
    String? comment,
    String contentVersion,
    DateTime now,
  ) => u.db.execute(
    'INSERT INTO content_reports(id, item_id, kind, comment, '
    'content_version, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [UserDb.newId(), itemId, kind, comment, contentVersion, _ms(now)],
  );

  /// Applies content deprecations: moves cards to a new id, or suspends
  /// cards whose item was removed. History stays in review_log.
  int applyDeprecations(Map<String, String?> map) {
    var changed = 0;
    u.tx(() {
      for (final c in cards().values) {
        if (!map.containsKey(c.itemId)) continue;
        final newItem = map[c.itemId];
        if (newItem == null) {
          u.db.execute('UPDATE cards SET suspended = 1 WHERE id = ?', [c.id]);
        } else {
          final newId = cardIdFor(newItem, c.facet);
          u.db.execute(
            'UPDATE OR IGNORE cards SET id = ?, item_id = ? WHERE id = ?',
            [newId, newItem, c.id],
          );
        }
        changed++;
      }
    });
    return changed;
  }
}

class LedgerRepo {
  final UserDb u;
  LedgerRepo(this.u);

  int balance() =>
      (u.db
                  .select('SELECT COALESCE(SUM(delta), 0) FROM coin_ledger')
                  .first
                  .columnAt(0)
              as num)
          .toInt();

  bool has(String key) => u.db.select(
    'SELECT 1 FROM coin_ledger WHERE idempotency_key = ?',
    [key],
  ).isNotEmpty;

  /// Inserts entries; duplicates (same idempotency key) are skipped and a
  /// spend that would overdraw throws. Returns the entries actually added.
  List<LedgerEntry> insertAll(List<LedgerEntry> entries) {
    final added = <LedgerEntry>[];
    for (final e in entries) {
      if (has(e.idempotencyKey)) continue;
      if (e.delta < 0 && balance() + e.delta < 0) {
        throw StateError('Lincoin ไม่พอ');
      }
      u.db.execute(
        'INSERT INTO coin_ledger(id, ts_utc, study_day, delta, reason, '
        'ref_id, idempotency_key, meta_json) VALUES (?,?,?,?,?,?,?,?)',
        [
          e.id,
          e.tsUtc.millisecondsSinceEpoch,
          e.studyDay,
          e.delta,
          e.reason,
          e.refId,
          e.idempotencyKey,
          e.meta.isEmpty ? null : jsonEncode(e.meta),
        ],
      );
      added.add(e);
    }
    return added;
  }

  List<LedgerEntry> entries({int? fromDay, int? limit}) {
    final rows = u.db.select(
      'SELECT * FROM coin_ledger WHERE study_day >= ? '
      'ORDER BY ts_utc DESC ${limit == null ? '' : 'LIMIT $limit'}',
      [fromDay ?? -1],
    );
    return [
      for (final r in rows)
        LedgerEntry(
          id: r['id'] as String,
          tsUtc: DateTime.fromMillisecondsSinceEpoch(
            r['ts_utc'] as int,
            isUtc: true,
          ),
          delta: r['delta'] as int,
          reason: r['reason'] as String,
          idempotencyKey: r['idempotency_key'] as String,
          refId: r['ref_id'] as String?,
          studyDay: r['study_day'] as int,
          meta: r['meta_json'] == null
              ? const {}
              : (jsonDecode(r['meta_json'] as String) as Map<String, Object?>),
        ),
    ];
  }

  DailyTotals totalsFor(int studyDay) => DailyTotals.fromEntries(
    entries(fromDay: studyDay).where((e) => e.studyDay == studyDay),
  );
}
