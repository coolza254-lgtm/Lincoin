import 'dart:io';

import '../data/content_db.dart';
import 'files.dart';

class ContentInstallResult {
  final bool ok;
  final List<String> problems;
  final String? version;
  const ContentInstallResult.ok(this.version) : ok = true, problems = const [];
  const ContentInstallResult.failed(this.problems) : ok = false, version = null;
}

/// Owns content.db on disk: first install from the bundled copy, atomic
/// replacement on update and one-step rollback. See docs/10-updates.md.
class ContentStore {
  final Directory dir;
  ContentStore(this.dir);

  File get current => File('${dir.path}/content.db');
  File get previous => File('${dir.path}/content.prev.db');

  String? installedVersion() {
    if (!current.existsSync()) return null;
    final db = ContentDb.openFile(current.path);
    try {
      return db.info().version;
    } finally {
      db.close();
    }
  }

  /// Validates [candidate] and swaps it in. The old file is kept as
  /// [previous]. [allowOlder] is for rollback only.
  Future<ContentInstallResult> install(
    File candidate, {
    String? expectedSha256,
    bool allowOlder = false,
  }) async {
    if (expectedSha256 != null) {
      final actual = await sha256OfFile(candidate);
      if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
        return const ContentInstallResult.failed([
          'ไฟล์ไม่ตรงกับค่าตรวจสอบ (sha256) อาจดาวน์โหลดไม่ครบ',
        ]);
      }
    }
    final problems = validateContentDb(candidate.path);
    if (problems.isNotEmpty) return ContentInstallResult.failed(problems);
    final db = ContentDb.openFile(candidate.path);
    final version = db.info().version;
    db.close();
    final installed = installedVersion();
    if (!allowOlder &&
        installed != null &&
        compareVersions(version, installed) < 0) {
      return ContentInstallResult.failed([
        'เนื้อหาเวอร์ชัน $version เก่ากว่าที่ติดตั้งอยู่ ($installed)',
      ]);
    }
    dir.createSync(recursive: true);
    // Copy next to the target first so the final rename is atomic.
    final staged = File('${dir.path}/content.new.db');
    if (staged.existsSync()) staged.deleteSync();
    await candidate.copy(staged.path);
    if (current.existsSync()) {
      if (previous.existsSync()) previous.deleteSync();
      current.renameSync(previous.path);
    }
    staged.renameSync(current.path);
    return ContentInstallResult.ok(version);
  }

  /// Swaps back to the previous content version.
  bool rollback() {
    if (!previous.existsSync()) return false;
    final tmp = File('${dir.path}/content.swap.db');
    if (current.existsSync()) current.renameSync(tmp.path);
    previous.renameSync(current.path);
    if (tmp.existsSync()) tmp.renameSync(previous.path);
    return true;
  }

  String? previousVersion() {
    if (!previous.existsSync()) return null;
    final db = ContentDb.openFile(previous.path);
    try {
      return db.info().version;
    } finally {
      db.close();
    }
  }
}
