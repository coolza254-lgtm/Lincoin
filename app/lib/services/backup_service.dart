import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../data/user_db.dart';

class BackupFile {
  final File file;
  final DateTime createdUtc;
  final String reason;
  const BackupFile(this.file, this.createdUtc, this.reason);
}

/// Copies of user.db. Taken automatically before every update, restore and
/// migration; the newest [keep] automatic copies are kept.
class BackupService {
  final Directory dir;
  final int keep;
  BackupService(this.dir, {this.keep = 5});

  static final _name = RegExp(r'^user-(\d{8}T\d{6})Z-([a-z_]+)\.db$');

  /// Consistent copy of the live database (VACUUM INTO works with WAL).
  File backup(UserDb db, String reason, {DateTime? nowUtc}) {
    dir.createSync(recursive: true);
    final t = (nowUtc ?? DateTime.now().toUtc());
    final stamp = t
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .substring(0, 15);
    final f = File('${dir.path}/user-${stamp}Z-$reason.db');
    if (f.existsSync()) f.deleteSync();
    db.db.execute('VACUUM INTO ?', [f.path]);
    _prune();
    return f;
  }

  /// Backup of a closed database file (before a migration).
  File backupFile(String path, String reason, {DateTime? nowUtc}) {
    dir.createSync(recursive: true);
    final t = (nowUtc ?? DateTime.now().toUtc());
    final stamp = t
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .substring(0, 15);
    final f = File('${dir.path}/user-${stamp}Z-$reason.db');
    final src = sqlite3.open(path);
    try {
      if (f.existsSync()) f.deleteSync();
      src.execute('VACUUM INTO ?', [f.path]);
    } finally {
      src.close();
    }
    _prune();
    return f;
  }

  List<BackupFile> list() {
    if (!dir.existsSync()) return const [];
    final out = <BackupFile>[];
    for (final e in dir.listSync().whereType<File>()) {
      final m = _name.firstMatch(e.uri.pathSegments.last);
      if (m == null) continue;
      final s = m.group(1)!;
      final t = DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(9, 11)),
        int.parse(s.substring(11, 13)),
        int.parse(s.substring(13, 15)),
      );
      out.add(BackupFile(e, t, m.group(2)!));
    }
    out.sort((a, b) => b.createdUtc.compareTo(a.createdUtc));
    return out;
  }

  void _prune() {
    final all = list();
    for (final b in all.skip(keep)) {
      b.file.deleteSync();
    }
  }

  /// Checks that [path] is a Lincoin user database this app can open.
  static List<String> validate(String path) {
    final problems = <String>[];
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final v = db.select('PRAGMA user_version').first.columnAt(0) as int;
      if (v == 0) problems.add('ไม่ใช่ไฟล์ข้อมูลของ Lincoin');
      if (v > UserDb.schemaVersion) {
        problems.add('ไฟล์มาจากแอปเวอร์ชันใหม่กว่า กรุณาอัปเดตแอปก่อน');
      }
      final tables = {
        for (final r in db.select(
          "SELECT name FROM sqlite_master WHERE type='table'",
        ))
          r['name'] as String,
      };
      for (final t in const ['meta', 'cards', 'review_log', 'coin_ledger']) {
        if (!tables.contains(t)) problems.add('ไม่มีตาราง $t');
      }
      if (problems.isEmpty) {
        final ok = db.select('PRAGMA quick_check').first.columnAt(0);
        if (ok != 'ok') problems.add('ไฟล์เสียหาย');
      }
    } on SqliteException {
      problems.add('เปิดไฟล์ไม่ได้ หรือไม่ใช่ฐานข้อมูล');
    } finally {
      db?.close();
    }
    return problems;
  }

  /// Replaces the database file at [target] with [source] (the live
  /// database must be closed first).
  static void replaceDatabase(String source, String target) {
    for (final suffix in ['-wal', '-shm']) {
      final f = File('$target$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final staged = File('$target.restore');
    File(source).copySync(staged.path);
    staged.renameSync(target);
  }
}
