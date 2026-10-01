import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lincoin/app.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/features/settings/settings_screen.dart';
import 'package:lincoin/services/content_store.dart';
import 'package:lincoin/services/files.dart';
import 'package:lincoin/state/providers.dart';
import 'package:lincoin/ui/tokens.g.dart';

import '../support/fixture.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('lincoin_widget');
    paths = AppPaths(tmp)..ensure();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ProviderContainer> start(
    WidgetTester tester, {
    bool content = true,
    AppSettings? settings,
    bool onboarding = false,
  }) async {
    if (content) {
      await tester.runAsync(() async {
        final f = File(fixtureContentFile(paths.tmp.path));
        await ContentStore(paths.content).install(f);
      });
    }
    if (!onboarding) {
      final db = UserDb.open(paths.userDb);
      if (settings != null) SettingsRepo(db).save(settings, DateTime.utc(2026));
      db.setMeta('onboarded', '1');
      db.close();
    }
    final container = ProviderContainer(
      overrides: [
        pathsProvider.overrideWithValue(paths),
        appVersionProvider.overrideWithValue(const AppVersion('0.1.0', 1)),
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('', 404)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LincoinApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('without content the home screen points to updates', (
    tester,
  ) async {
    await start(tester, content: false);
    expect(find.text('ยังไม่มีเนื้อหา'), findsOneWidget);
    await tester.tap(find.text('ไปหน้าอัปเดต'));
    await tester.pumpAndSettle();
    expect(find.text('ตรวจหาอัปเดต'), findsOneWidget);
    expect(find.text('อัปเดตจากไฟล์'), findsOneWidget);
  });

  testWidgets('first run: onboarding sets kana and pace', (tester) async {
    final c = await start(tester, onboarding: true);
    expect(find.text('ยินดีต้อนรับสู่ Lincoin'), findsOneWidget);
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อ่านได้แล้ว ข้ามไป N5'));
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ใหม่ 20 ใบ/วัน'));
    await tester.tap(find.text('เริ่มเลย'));
    await tester.pumpAndSettle();
    expect(find.text('ท่องศัพท์'), findsOneWidget);
    final s = c.read(settingsProvider);
    expect(s.includeKana, isFalse);
    expect(s.vocabNewPerDay, 20);
  });

  testWidgets('a full study session records reviews', (tester) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false, vocabNewPerDay: 3),
    );
    expect(find.text('ท่องศัพท์'), findsOneWidget);
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();

    var intros = 0, questions = 0;
    for (var i = 0; i < 80; i++) {
      if (find.text('กลับหน้าหลัก').evaluate().isNotEmpty) break;
      if (find.text('จำแล้ว ไปต่อ').evaluate().isNotEmpty) {
        intros++;
        await tester.tap(find.text('จำแล้ว ไปต่อ'));
      } else if (find.text('ต่อไป').evaluate().isNotEmpty) {
        await tester.tap(find.text('ต่อไป'));
      } else if (find.text('ความหมายคืออะไร').evaluate().isNotEmpty ||
          find.text('เติมคำในช่องว่าง').evaluate().isNotEmpty) {
        questions++;
        await tester.tap(find.byType(OutlinedButton).first);
      } else {
        fail('unexpected screen at step $i');
      }
      await tester.pumpAndSettle();
    }
    expect(intros, 3);
    expect(questions, greaterThanOrEqualTo(3));
    expect(find.text('กลับหน้าหลัก'), findsOneWidget);
    final log = StudyRepo(c.read(userDbProvider)).reviewRecords();
    expect(log.length, questions);
    await tester.tap(find.text('กลับหน้าหลัก'));
    await tester.pumpAndSettle();
    expect(find.text('ท่องศัพท์'), findsOneWidget);
  });

  testWidgets('a grammar session: lesson, cloze, feedback', (tester) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false, grammarNewPerDay: 1),
    );
    expect(find.text('ไวยากรณ์'), findsWidgets);
    await tester.tap(find.text('เริ่มเรียน').last);
    await tester.pumpAndSettle();
    expect(find.text('ไวยากรณ์ใหม่'), findsOneWidget);
    expect(find.text('วิธีใช้'), findsWidgets);
    await tester.tap(find.text('จำแล้ว ไปต่อ'));
    await tester.pumpAndSettle();
    expect(find.text('เติมคำในช่องว่าง'), findsOneWidget);
    expect(find.text('ดื่มน้ำแล้ว'), findsOneWidget); // Thai cue
    await tester.tap(find.widgetWithText(OutlinedButton, 'を'));
    await tester.pumpAndSettle();
    expect(find.text('ถูกต้อง'), findsOneWidget);
    final log = StudyRepo(c.read(userDbProvider))
        .reviewRecords(deck: 'grammar');
    expect(log, hasLength(1));
  });

  testWidgets('every theme renders all tabs', (tester) async {
    for (final theme in LcTokens.themes.keys) {
      await start(tester, settings: AppSettings(theme: theme));
      for (final tab in ['ฝึก & ท้าทาย', 'สถิติ', 'ร้าน', 'หน้าหลัก']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('shop: add a reward', (tester) async {
    await start(tester);
    await tester.tap(find.text('ร้าน').last);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีรางวัล'), findsOneWidget);
    await tester.tap(find.text('เพิ่มรางวัล'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อรางวัล'),
      'ชานม',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ราคา (Lincoin)'),
      '120',
    );
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('ชานม'), findsOneWidget);
    expect(find.text('อีก 120 Lincoin'), findsOneWidget);
  });

  testWidgets('settings open and change a value', (tester) async {
    final c = await start(tester);
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มจากคานะ'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).includeKana, isFalse);
    await tester.scrollUntilVisible(find.text('เครดิตและสัญญาอนุญาต'), 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เครดิตและสัญญาอนุญาต'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เครดิตและสัญญาอนุญาต'));
    await tester.pumpAndSettle();
    expect(find.text('Source jlpt'), findsOneWidget);
  });

  testWidgets('focus mode with a controller: answer with buttons', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(
        includeKana: false,
        vocabNewPerDay: 3,
        reduceMotion: true,
        quickAnswerButtons: true,
      ),
    );
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    var questions = 0;
    for (var i = 0; i < 80; i++) {
      if (find.text('กลับหน้าหลัก').evaluate().isNotEmpty) break;
      if (find.text('จำแล้ว ไปต่อ').evaluate().isNotEmpty) {
        await tester.tap(find.text('จำแล้ว ไปต่อ'));
      } else if (find.text('ต่อไป').evaluate().isNotEmpty) {
        // "Next" takes focus, so the confirm button moves on.
        await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      } else if (find.text('X').evaluate().isNotEmpty) {
        // Quick-answer badges are shown; X picks the third answer.
        questions++;
        await tester.sendKeyEvent(
          questions.isEven
              ? LogicalKeyboardKey.gameButtonX
              : LogicalKeyboardKey.digit1,
        );
      } else {
        fail('unexpected screen at step $i');
      }
      await tester.pumpAndSettle();
    }
    expect(questions, greaterThanOrEqualTo(3));
    expect(StudyRepo(c.read(userDbProvider)).reviewRecords().length, questions);
  });

  testWidgets('controller: B goes back, shoulder buttons switch tabs', (
    tester,
  ) async {
    await start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
    await tester.pumpAndSettle();
    expect(find.text('ฝึก'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonLeft1);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
