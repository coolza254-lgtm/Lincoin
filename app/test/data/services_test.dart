import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lincoin/data/content_db.dart';
import 'package:lincoin/data/shop_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/services/backup_service.dart';
import 'package:lincoin/services/content_pack.dart';
import 'package:lincoin/services/content_store.dart';
import 'package:lincoin/services/update_service.dart';
import 'package:lincoin_core/lincoin_core.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixture.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lincoin'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('ContentStore', () {
    test('installs, refuses older, rolls back', () async {
      final store = ContentStore(Directory('${tmp.path}/content'));
      final v1 = File(fixtureContentFile(tmp.path, version: '2026.09.30'));
      final v2 = File(fixtureContentFile(tmp.path, version: '2026.10.1'));
      expect((await store.install(v1)).ok, isTrue);
      expect(store.installedVersion(), '2026.09.30');
      final r2 = await store.install(
        v2,
        expectedSha256: sha256.convert(v2.readAsBytesSync()).toString(),
      );
      expect(r2.ok, isTrue);
      expect(store.installedVersion(), '2026.10.1');
      expect((await store.install(v1)).ok, isFalse);
      expect(store.rollback(), isTrue);
      expect(store.installedVersion(), '2026.09.30');
      expect(store.previousVersion(), '2026.10.1');
    });

    test('rejects bad hash and files without credits', () async {
      final store = ContentStore(Directory('${tmp.path}/content'));
      final v1 = File(fixtureContentFile(tmp.path));
      final bad = await store.install(v1, expectedSha256: '00');
      expect(bad.ok, isFalse);
      final raw = File('${tmp.path}/nocredit.db');
      v1.copySync(raw.path);
      final w = sqlite3.open(raw.path);
      w.execute('DELETE FROM sources');
      w.close();
      expect(validateContentDb(raw.path), contains('ข้อมูลเครดิตไม่ครบ'));
      expect((await store.install(raw)).ok, isFalse);
      expect(validateContentDb('${tmp.path}/missing.db'), isNotEmpty);
    });
  });

  test('content pack round trip', () async {
    final dbFile = File(fixtureContentFile(tmp.path));
    final bytes = dbFile.readAsBytesSync();
    final manifest = {
      'format': 1,
      'version': '2026.09.30',
      'schemaVersion': 1,
      'sha256': sha256.convert(bytes).toString(),
      'minAppVersionCode': 1,
    };
    final a = Archive()
      ..add(ArchiveFile.bytes('content.db', bytes))
      ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    final pack = File('${tmp.path}/x.lincoin-content')
      ..writeAsBytesSync(ZipEncoder().encode(a));
    final ex = await extractContentPack(pack, Directory('${tmp.path}/t'));
    expect(ex.manifest.version, '2026.09.30');
    final store = ContentStore(Directory('${tmp.path}/content'));
    expect(
      (await store.install(ex.db, expectedSha256: ex.manifest.sha256)).ok,
      isTrue,
    );
    await expectLater(
      extractContentPack(dbFile, Directory('${tmp.path}/t')),
      throwsA(isA<ContentPackException>()),
    );
  });

  test('backup, validate, prune and restore', () {
    final path = '${tmp.path}/user.db';
    final db = UserDb.open(path);
    SettingsRepo(db)
        .save(const AppSettings(vocabNewPerDay: 7), DateTime.utc(2026));
    final backups = BackupService(Directory('${tmp.path}/b'), keep: 3);
    for (var i = 0; i < 5; i++) {
      backups.backup(db, 'auto', nowUtc: DateTime.utc(2026, 1, 1, 0, 0, i));
    }
    final list = backups.list();
    expect(list, hasLength(3));
    expect(list.first.createdUtc, DateTime.utc(2026, 1, 1, 0, 0, 4));
    expect(BackupService.validate(list.first.file.path), isEmpty);
    SettingsRepo(db)
        .save(const AppSettings(vocabNewPerDay: 20), DateTime.utc(2026));
    db.close();
    BackupService.replaceDatabase(list.first.file.path, path);
    final back = UserDb.open(path);
    expect(SettingsRepo(back).load().vocabNewPerDay, 7);
    back.close();
    File('${tmp.path}/junk.db').writeAsStringSync('not a db');
    expect(BackupService.validate('${tmp.path}/junk.db'), isNotEmpty);
  });

  group('updates', () {
    final manifest = {
      'app': {
        'versionCode': 5,
        'versionName': '0.2.0',
        'apkUrl': 'https://example.org/a.apk',
        'sha256': 'x',
        'sizeBytes': 10,
      },
      'content': {
        'version': '2026.10.1',
        'url': 'https://example.org/c.lincoin-content',
        'sha256': 'y',
        'sizeBytes': 10,
        'minAppVersionCode': 5,
      },
    };

    test('compare picks newer app; content waits for the app it needs', () {
      final m = LatestManifest.fromJson(manifest);
      final now = DateTime.utc(2026);
      final c = compareWithInstalled(
        m,
        appVersionCode: 4,
        contentVersion: '2026.09.30',
        nowUtc: now,
      );
      expect(c.appUpdate?.versionName, '0.2.0');
      expect(c.contentUpdate, isNull);
      expect(c.contentNeedsNewerApp, isTrue);
      final c2 = compareWithInstalled(
        m,
        appVersionCode: 5,
        contentVersion: '2026.09.30',
        nowUtc: now,
      );
      expect(c2.appUpdate, isNull);
      expect(c2.contentUpdate?.version, '2026.10.1');
      final c3 = compareWithInstalled(
        m,
        appVersionCode: 5,
        contentVersion: '2026.10.1',
        nowUtc: now,
      );
      expect(c3.hasAny, isFalse);
    });

    test('fetch and verified, resumable download', () async {
      final body = utf8.encode('hello update');
      final hash = sha256.convert(body).toString();
      var calls = 0;
      final client = MockClient.streaming((req, _) async {
        calls++;
        if (req.url.path.endsWith('latest.json')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(manifest))),
            200,
          );
        }
        final range = req.headers['Range'];
        if (range != null) {
          final from = int.parse(range.substring(6, range.length - 1));
          return http.StreamedResponse(Stream.value(body.sublist(from)), 206);
        }
        return http.StreamedResponse(Stream.value(body), 200);
      });
      final svc = UpdateService(
        client,
        manifestUri: Uri.parse('https://example.org/latest.json'),
      );
      expect((await svc.fetchLatest()).app!.versionCode, 5);
      final target = File('${tmp.path}/a.apk');
      File('${target.path}.part').writeAsBytesSync(body.sublist(0, 5));
      final f = await svc.download(
        'https://example.org/a.apk',
        target,
        sha256: hash,
      );
      expect(f.readAsBytesSync(), body);
      // A finished download is reused without a new request.
      await svc.download('https://example.org/a.apk', target, sha256: hash);
      await expectLater(
        svc.download(
          'https://example.org/a.apk',
          File('${tmp.path}/b'),
          sha256: 'bad',
        ),
        throwsA(isA<UpdateException>()),
      );
      expect(File('${tmp.path}/b.part').existsSync(), isFalse);
      expect(calls, 3);
    });
  });

  test('shop: redeem spends, cooldown and one-off rules, no overdraft', () {
    final db = UserDb.memory();
    final shop = ShopRepo(db);
    final now = DateTime.utc(2026, 10, 1);
    LedgerRepo(db).insertAll([
      LedgerEntry(
        id: 'l1',
        tsUtc: now,
        delta: 150,
        reason: LedgerReason.review,
        idempotencyKey: 'seed',
        studyDay: 1,
      ),
    ]);
    const tea = Reward(
      id: 'r1',
      title: 'ชานม',
      emoji: '🧋',
      price: 100,
      repeatable: true,
      cooldownDays: 2,
    );
    const game = Reward(
      id: 'r2',
      title: 'เกมใหม่',
      emoji: '🎮',
      price: 40,
      repeatable: false,
    );
    shop.save(tea, now);
    shop.save(game, now);
    expect(shop.canRedeem(tea, now), RedeemBlock.none);
    shop.redeem(tea, nowUtc: now, studyDay: 1);
    expect(LedgerRepo(db).balance(), 50);
    expect(shop.canRedeem(tea, now), RedeemBlock.cooldown);
    shop.redeem(game, nowUtc: now, studyDay: 1);
    expect(shop.canRedeem(game, now), RedeemBlock.alreadyRedeemed);
    expect(
      shop.canRedeem(tea, now.add(const Duration(days: 3))),
      RedeemBlock.notEnough,
    );
    expect(
      () => shop.redeem(
        tea,
        nowUtc: now.add(const Duration(days: 3)),
        studyDay: 4,
      ),
      throwsStateError,
    );
    expect(LedgerRepo(db).balance(), 10);
    shop.remove('r1');
    expect(shop.rewards().map((r) => r.id), ['r2']);
    expect(shop.redemptions(), hasLength(2));
  });

  test('settings: unknown values fall back to defaults', () {
    final s = AppSettings.fromMap({
      'theme': 'removed-theme',
      'vocab.desired_retention': '0.99',
      'vocab.new_per_day': '12',
      'furigana': 'never',
    });
    expect(s.theme, 'matcha');
    expect(s.vocabRetention, 0.90);
    expect(s.vocabNewPerDay, 12);
    expect(s.furigana, FuriganaMode.never);
  });

  test('migration from an empty file and version guard', () {
    final path = '${tmp.path}/m.db';
    var called = false;
    final db = UserDb.open(path, beforeMigrate: (_) => called = true);
    expect(db.version, UserDb.schemaVersion);
    expect(called, isFalse);
    db.db.execute('PRAGMA user_version = 99');
    db.close();
    expect(() => UserDb.open(path), throwsStateError);
  });
}
