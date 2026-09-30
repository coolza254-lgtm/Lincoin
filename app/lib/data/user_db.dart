import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// The learner's own data (progress, Lincoin, rewards). Never replaced by
/// content updates. See docs/03-database.md.
///
/// Times are stored as UTC milliseconds since the epoch.
class UserDb {
  final Database db;
  final String? path;

  UserDb._(this.db, this.path);

  static const int schemaVersion = 1;
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Opens (creating if needed) and migrates. [beforeMigrate] runs when an
  /// existing database is about to be upgraded, so a backup can be taken.
  static UserDb open(String path, {void Function(int from)? beforeMigrate}) {
    final existed = File(path).existsSync();
    final db = sqlite3.open(path);
    final u = UserDb._(db, path);
    final v = u.version;
    if (existed && v > 0 && v < schemaVersion) beforeMigrate?.call(v);
    u._migrate();
    return u;
  }

  static UserDb memory() => UserDb._(sqlite3.openInMemory(), null).._migrate();

  int get version => db.select('PRAGMA user_version').first.columnAt(0) as int;

  void close() => db.close();

  /// Runs [body] in a transaction; rolls back if it throws.
  T tx<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final r = body();
      db.execute('COMMIT');
      return r;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _migrate() {
    db.execute('PRAGMA foreign_keys = ON');
    if (path != null) db.execute('PRAGMA journal_mode = WAL');
    var v = version;
    if (v > schemaVersion) {
      throw StateError(
        'user.db schema $v is newer than this app '
        '($schemaVersion). Update the app first.',
      );
    }
    while (v < schemaVersion) {
      tx(() {
        for (final stmt in _migrations[v]) {
          db.execute(stmt);
        }
        db.execute('PRAGMA user_version = ${v + 1}');
      });
      v++;
    }
    if (_meta('device_id') == null) {
      db.execute("INSERT INTO meta(key, value) VALUES ('device_id', ?)", [
        newId(),
      ]);
    }
    db.execute(
      "INSERT OR REPLACE INTO meta(key, value) VALUES ('schema_version', ?)",
      ['$schemaVersion'],
    );
  }

  String? _meta(String key) {
    final r = db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  String? meta(String key) => _meta(key);
  void setMeta(String key, String value) => db.execute(
    'INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)',
    [key, value],
  );

  /// Index = version the migration starts from. Never edit a shipped entry;
  /// append a new one (and a test in test/data/migration_test.dart).
  static const List<List<String>> _migrations = [
    // 0 → 1: initial schema
    [
      'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL)',
      '''CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        deck TEXT NOT NULL,
        facet TEXT NOT NULL,
        status TEXT NOT NULL,
        suspended INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER,
        stability REAL,
        difficulty REAL,
        step_index INTEGER,
        reps INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        last_review_at INTEGER,
        last_rating INTEGER,
        introduced_at INTEGER NOT NULL,
        introduced_day INTEGER NOT NULL,
        first_mastered_at INTEGER,
        is_leech INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NOT NULL,
        updated_at INTEGER NOT NULL)''',
      'CREATE INDEX idx_cards_item ON cards(item_id)',
      'CREATE INDEX idx_cards_deck_due ON cards(deck, due_at)',
      '''CREATE TABLE review_log (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        deck TEXT NOT NULL,
        session_id TEXT,
        ts_utc INTEGER NOT NULL,
        tz_offset_min INTEGER NOT NULL,
        study_day INTEGER NOT NULL,
        question_type TEXT NOT NULL,
        answer_raw TEXT,
        is_correct INTEGER NOT NULL,
        used_hint INTEGER NOT NULL,
        marked_guess INTEGER NOT NULL,
        gave_up INTEGER NOT NULL,
        response_ms INTEGER NOT NULL,
        rating INTEGER NOT NULL,
        status_before TEXT NOT NULL,
        elapsed_days INTEGER NOT NULL,
        s_before REAL, d_before REAL, s_after REAL, d_after REAL,
        due_after INTEGER,
        r_predicted REAL,
        params_version INTEGER NOT NULL,
        algo_version INTEGER NOT NULL)''',
      'CREATE INDEX idx_review_card ON review_log(card_id, ts_utc)',
      'CREATE INDEX idx_review_day ON review_log(study_day)',
      '''CREATE TABLE practice_log (
        id TEXT PRIMARY KEY, card_id TEXT NOT NULL, session_id TEXT,
        mode TEXT NOT NULL, ts_utc INTEGER NOT NULL, study_day INTEGER NOT NULL,
        question_type TEXT NOT NULL, is_correct INTEGER NOT NULL,
        response_ms INTEGER NOT NULL)''',
      '''CREATE TABLE sessions (
        id TEXT PRIMARY KEY, mode TEXT NOT NULL, deck TEXT,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        study_day INTEGER NOT NULL,
        active_ms INTEGER NOT NULL DEFAULT 0,
        answered INTEGER NOT NULL DEFAULT 0,
        summary_json TEXT)''',
      '''CREATE TABLE fsrs_params (
        id TEXT PRIMARY KEY, deck TEXT NOT NULL, version INTEGER NOT NULL,
        weights_json TEXT NOT NULL, created_at INTEGER NOT NULL,
        log_loss_before REAL, log_loss_after REAL,
        is_active INTEGER NOT NULL DEFAULT 0)''',
      '''CREATE TABLE coin_ledger (
        id TEXT PRIMARY KEY,
        ts_utc INTEGER NOT NULL,
        study_day INTEGER NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        ref_id TEXT,
        idempotency_key TEXT NOT NULL UNIQUE,
        meta_json TEXT,
        note TEXT)''',
      'CREATE INDEX idx_ledger_day ON coin_ledger(study_day)',
      '''CREATE TABLE rewards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        emoji TEXT NOT NULL,
        price INTEGER NOT NULL CHECK (price > 0),
        repeatable INTEGER NOT NULL,
        cooldown_days INTEGER,
        condition_json TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL)''',
      '''CREATE TABLE redemptions (
        id TEXT PRIMARY KEY, reward_id TEXT NOT NULL REFERENCES rewards(id),
        ledger_id TEXT NOT NULL, ts_utc INTEGER NOT NULL,
        price INTEGER NOT NULL, title TEXT NOT NULL, note TEXT)''',
      '''CREATE TABLE challenges (
        id TEXT PRIMARY KEY, type TEXT NOT NULL, tier TEXT NOT NULL,
        stake INTEGER NOT NULL, multiplier REAL NOT NULL,
        target_json TEXT NOT NULL, started_at INTEGER NOT NULL,
        finished_at INTEGER, result TEXT NOT NULL, score REAL,
        stake_ledger_id TEXT, payout_ledger_id TEXT)''',
      '''CREATE TABLE config_versions (
        key TEXT NOT NULL, version INTEGER NOT NULL, json TEXT NOT NULL,
        activated_at INTEGER NOT NULL, PRIMARY KEY (key, version))''',
      '''CREATE TABLE translation_overrides (
        sense_id TEXT PRIMARY KEY, gloss_th TEXT NOT NULL, note_th TEXT,
        updated_at INTEGER NOT NULL)''',
      '''CREATE TABLE content_reports (
        id TEXT PRIMARY KEY, item_id TEXT NOT NULL, kind TEXT NOT NULL,
        comment TEXT, content_version TEXT, created_at INTEGER NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0)''',
    ],
  ];
}
