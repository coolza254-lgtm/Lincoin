// Renders the main screens with real fonts and content for design review.
//
//   cp <content.db> test_screens/content.db
//   flutter test test_screens --update-goldens
//
// Not part of CI (font rendering differs between machines).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lincoin/app.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/content_db.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/shop_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/services/content_store.dart';
import 'package:lincoin/services/files.dart';
import 'package:lincoin/services/study_service.dart';
import 'package:lincoin/state/providers.dart';
import 'package:lincoin_core/lincoin_core.dart';

Future<void> loadFonts() async {
  Future<ByteData> file(String p) async =>
      ByteData.sublistView(await File(p).readAsBytes());
  final thai = FontLoader('IBMPlexSansThai');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    thai.addFont(file('assets/fonts/IBMPlexSansThai-$w.ttf'));
  }
  await thai.load();
  final jp = FontLoader('ZenMaruGothic');
  for (final w in ['Medium', 'Bold']) {
    jp.addFont(file('assets/fonts/ZenMaruGothic-$w.ttf'));
  }
  await jp.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  await (FontLoader('MaterialIcons')..addFont(
        file(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ))
      .load();
}

void main() {
  late Directory tmp;
  late AppPaths paths;
  final now = DateTime.utc(2026, 10, 1, 5);

  setUpAll(loadFonts);
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lincoin_shots');
    paths = AppPaths(tmp)..ensure();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Three weeks of simulated study so stats and home have data.
  void seedHistory(String theme) {
    final db = UserDb.open(paths.userDb);
    final settings = AppSettings(theme: theme, includeKana: false);
    SettingsRepo(db).save(settings, now);
    db.setMeta('onboarded', '1');
    final content = ContentDb.openFile('${paths.content.path}/content.db');
    final catalog = Catalog.load(content);
    var t = now.subtract(const Duration(days: 21));
    for (var day = 0; day < 21; day++) {
      final svc = StudyService(
        db: db,
        catalog: catalog,
        settings: settings,
        clock: Clock(() => t, () => 420),
      );
      final order = svc.sessionOrder(svc.plan());
      for (final (i, id) in order.indexed) {
        final q = svc.question(id);
        if (q.needsIntro) svc.introduce(q);
        final ok = fnv1a32('$id$day') % 10 < 8;
        final r = svc.answer(
          q,
          AnswerEvent(isCorrect: ok, responseMs: 4000 + i * 37 % 3000),
        );
        if (r.outcome.after.inSteps) {
          t = t.add(const Duration(minutes: 11));
          svc.answer(q, const AnswerEvent(isCorrect: true, responseMs: 4500));
          t = t.add(const Duration(minutes: 11));
          if (svc.stored(id)!.state.inSteps) {
            svc.answer(q, const AnswerEvent(isCorrect: true, responseMs: 4500));
          }
        }
        t = t.add(const Duration(seconds: 20));
      }
      svc.finishSession(answeredAny: true);
      t = DateTime.utc(t.year, t.month, t.day + 1, 5);
    }
    final shop = ShopRepo(db);
    shop.save(
      const Reward(
        id: 'a',
        title: 'ชานมไข่มุก',
        emoji: '🧋',
        price: 150,
        repeatable: true,
        cooldownDays: 3,
      ),
      now,
    );
    shop.save(
      const Reward(
        id: 'b',
        title: 'ดูหนังโรง 1 เรื่อง',
        emoji: '🎬',
        price: 600,
        repeatable: true,
      ),
      now,
    );
    shop.save(
      const Reward(
        id: 'c',
        title: 'หนังสือการ์ตูนญี่ปุ่นเล่มแรก',
        emoji: '📚',
        price: 2500,
        repeatable: false,
      ),
      now,
    );
    content.close();
    db.close();
  }

  Future<void> shoot(WidgetTester tester, String theme) async {
    await tester.runAsync(() async {
      await ContentStore(paths.content)
          .install(File('test_screens/content.db'));
    });
    seedHistory(theme);
    final container = ProviderContainer(
      overrides: [
        pathsProvider.overrideWithValue(paths),
        appVersionProvider.overrideWithValue(const AppVersion('0.1.0', 1)),
        clockProvider.overrideWithValue(Clock(() => now, () => 420)),
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('', 404)),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LincoinApp(),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> snap(String name) async {
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/$theme-$name.png'),
      );
    }

    await snap('1-home');
    for (final (tab, name) in [
      ('สถิติ', '2-stats'),
      ('ร้าน', '3-shop'),
      ('ฝึก & ท้าทาย', '4-practice'),
    ]) {
      await tester.tap(find.text(tab).last);
      await snap(name);
    }
    if (theme != 'matcha') return;
    // Challenge tab + setup sheet, then a practice round.
    await tester.tap(find.text('ท้าทาย'));
    await snap('4b-challenges');
    await tester.tap(find.text('สปีดรอบ'));
    await snap('4c-challenge-setup');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ฝึก').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มฝึก 10 ข้อ'));
    await tester.pumpAndSettle();
    await snap('4d-drill');
    final opt = find.byType(OutlinedButton);
    if (opt.evaluate().isNotEmpty) {
      await tester.tap(opt.first);
      await snap('4e-drill-feedback');
    }
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('หน้าหลัก').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    var intro = false, choice = false, typed = false, feedback = false;
    for (var i = 0; i < 60 && !(intro && choice && typed && feedback); i++) {
      if (find.text('จำแล้ว ไปต่อ').evaluate().isNotEmpty) {
        if (!intro) await snap('5-intro');
        intro = true;
        await tester.tap(find.text('จำแล้ว ไปต่อ'));
      } else if (find.text('ความหมายคืออะไร').evaluate().isNotEmpty) {
        if (!choice) await snap('6-question');
        choice = true;
        await tester.tap(find.byType(OutlinedButton).at(1));
      } else if (find.text('พิมพ์คำอ่าน').evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'tabe');
        if (!typed) await snap('7-typed');
        typed = true;
        await tester.tap(find.text('ไม่รู้'));
      } else if (find.text('ต่อไป').evaluate().isNotEmpty) {
        if (!feedback) await snap('8-feedback');
        feedback = true;
        await tester.tap(find.text('ต่อไป'));
      } else {
        break;
      }
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await snap('9-settings');
  }

  for (final theme in ['matcha', 'sakura', 'mono', 'dark']) {
    testWidgets('screens $theme', (tester) => shoot(tester, theme));
  }
}
