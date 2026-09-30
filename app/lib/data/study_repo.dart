import 'dart:convert';

import 'package:lincoin_core/lincoin_core.dart';
import 'package:sqlite3/sqlite3.dart' show Row;

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

class StudyRepo {
  final UserDb u;
  StudyRepo(this.u);

  static int? _ms(DateTime? t) => t?.millisecondsSinceEpoch;
  static DateTime? _dt(Object? ms) => ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

  Map<String, StoredCard> cards({String? deck}) {
    final rows = deck == null
        ? u.db.select('SELECT * FROM cards')
        : u.db.select('SELECT * FROM cards WHERE deck = ?', [deck]);
    return {for (final r in rows) r['id'] as String: _card(r)};
  }

  StoredCard? card(String id) {
    final rows = u.db.select('SELECT * FROM cards WHERE id = ?', [id]);
    return rows.isEmpty ? null : _card(rows.first);
  }

  StoredCard _card(Row r) => StoredCard(
    id: r['id'] as String,
    itemId: r['item_id'] as String,
    deck: r['deck'] as String,
    facet: Facet.tryParse(r['facet'] as String) ?? Facet.recog,
    state: CardState(
      status: CardStatus.values.byName(r['status'] as String),
      step: r['step_index'] as int?,
      stability: (r['stability'] as num?)?.toDouble(),
      difficulty: (r['difficulty'] as num?)?.toDouble(),
      due: _dt(r['due_at']),
      lastReview: _dt(r['last_review_at']),
      lastRating: r['last_rating'] == null
          ? null
          : Rating.fromValue(r['last_rating'] as int),
      reps: r['reps'] as int,
      lapses: r['lapses'] as int,
    ),
    suspended: (r['suspended'] as int) == 1,
    isLeech: (r['is_leech'] as int) == 1,
    introducedDay: r['introduced_day'] as int,
    firstMasteredAt: _dt(r['first_mastered_at']),
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
          cardId: r['card_id'] as String,
          deck: r['deck'] as String,
          tsUtc: _dt(r['ts_utc'])!,
          studyDay: r['study_day'] as int,
          statusBefore: CardStatus.values.byName(r['status_before'] as String),
          rating: Rating.fromValue(r['rating'] as int),
          rPredicted: (r['r_predicted'] as num?)?.toDouble(),
          responseMs: r['response_ms'] as int,
        ),
    ];
  }

  /// Recent correct, unassisted answers per question type, to seed the
  /// grader's personal response-time median.
  ResponseTimeTracker responseTimes({int perType = 200}) {
    final t = ResponseTimeTracker(window: perType);
    final rows = u.db.select(
      'SELECT question_type, response_ms FROM ('
      '  SELECT question_type, response_ms, ts_utc, ROW_NUMBER() OVER '
      '  (PARTITION BY question_type ORDER BY ts_utc DESC) AS n '
      '  FROM review_log WHERE is_correct = 1 AND used_hint = 0 '
      '  AND marked_guess = 0 AND gave_up = 0'
      ') WHERE n <= ? ORDER BY ts_utc',
      [perType],
    );
    for (final r in rows) {
      t.add(
        r['question_type'] as String,
        AnswerEvent(isCorrect: true, responseMs: r['response_ms'] as int),
      );
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
