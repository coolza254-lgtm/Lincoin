import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lincoin_core/lincoin_core.dart' show Rating;
import 'package:lincoin/app.dart';
import 'package:lincoin/features/study/session_controller.dart';
import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/settings_repo.dart';
import 'package:lincoin/data/study_repo.dart';
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/features/settings/settings_screen.dart';
import 'package:lincoin/services/content_store.dart';
import 'package:lincoin/services/files.dart';
import 'package:lincoin/state/providers.dart';
import 'package:lincoin/ui/theme.dart';
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

  testWidgets('flashcards: flip, rate yourself, Again comes back', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false, vocabNewPerDay: 2),
    );
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    var flips = 0, again = 0;
    for (var i = 0; i < 60; i++) {
      if (find.text('กลับหน้าหลัก').evaluate().isNotEmpty) break;
      if (find.text('แสดงคำตอบ').evaluate().isNotEmpty) {
        // No quiz and no separate introduction: the word alone.
        expect(find.text('ความหมายคืออะไร'), findsNothing);
        flips++;
        await tester.tap(find.text('แสดงคำตอบ'));
      } else if (find.text('ดี').evaluate().isNotEmpty) {
        // Anki-style buttons show when the card would come back.
        expect(find.textContaining('นาที'), findsWidgets);
        if (again == 0) {
          again++;
          await tester.tap(find.text('อีกครั้ง'));
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
        }
      } else {
        fail('unexpected screen at step $i');
      }
      await tester.pumpAndSettle();
    }
    expect(find.text('กลับหน้าหลัก'), findsOneWidget);
    final log = StudyRepo(c.read(userDbProvider)).reviewRecords();
    expect(log.length, flips);
    expect(flips, greaterThan(2));
    expect(log.first.rating, Rating.again);
    // One card per word, as in Kaishi: no reverse cards are started.
    expect(log.every((r) => r.cardId.endsWith('#recog')), isTrue);
  });

  testWidgets('levels N5 → N1 are listed; one level can be played', (
    tester,
  ) async {
    final c = await start(tester);
    await tester.scrollUntilVisible(find.text('JLPT N1'), 300);
    await tester.pumpAndSettle();
    for (final l in ['N5', 'N4', 'N3', 'N2', 'N1']) {
      expect(find.text('JLPT $l'), findsOneWidget);
    }
    // Levels without content yet say so instead of offering to play.
    expect(find.text('เร็วๆ นี้'), findsNWidgets(4));
    await tester.ensureVisible(find.text('JLPT N5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JLPT N5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แสดงคำตอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ดี'));
    await tester.pumpAndSettle();
    final log = StudyRepo(c.read(userDbProvider)).reviewRecords();
    // N5 starts with words even though the whole path begins with kana.
    expect(log.single.cardId, 'w:1#recog');
  });

  testWidgets('quit midway, come back: carry on where you left off', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false, vocabNewPerDay: 5),
    );
    String current() => c.read(sessionProvider(vocabDeck)).question!.cardId;
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    final seen = <String>[];
    for (var i = 0; i < 2; i++) {
      seen.add(current());
      await tester.tap(find.text('แสดงคำตอบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ดี'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    // The two cards just answered wait for their step; the next new word
    // comes first, and the bar starts from today's work.
    expect(seen, isNot(contains(current())));
    expect(c.read(sessionProvider(vocabDeck)).doneBefore, 2);
    expect(c.read(sessionProvider(vocabDeck)).progress, greaterThan(0));
  });

  testWidgets('library: search a word and open its progress', (tester) async {
    await start(tester);
    await tester.tap(find.text('คลังคำ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'taberu');
    await tester.pumpAndSettle();
    expect(find.text('1 คำ'), findsOneWidget);
    await tester.tap(find.text('กิน'));
    await tester.pumpAndSettle();
    expect(find.text('ความคืบหน้าของคำ'), findsOneWidget);
    expect(find.text('ยังไม่เริ่ม'), findsOneWidget);
  });

  testWidgets('settings: pick a font; speaker toggles auto-play', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false),
    );
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ลายมือครู'), 300);
    await tester.ensureVisible(find.text('ลายมือครู'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลายมือครู'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).font, 'textbook');
    expect(AppFonts.japanese, 'KleeOne');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).autoPlayAudio, isFalse);
    await tester.tap(find.byTooltip('เปิดอ่านออกเสียงอัตโนมัติ'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).autoPlayAudio, isTrue);
    // Flipping with auto-play on still works without a voice installed.
    await tester.tap(find.text('แสดงคำตอบ'));
    await tester.pumpAndSettle();
    expect(find.text('ดี'), findsOneWidget);
    AppFonts.current = FontPreset.standard;
  });

  testWidgets('undo a mis-tap: the card comes back to rate again', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false, vocabNewPerDay: 3),
    );
    String current() => c.read(sessionProvider(vocabDeck)).question!.cardId;
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    final first = current();
    expect(find.byTooltip('เลิกทำการ์ดล่าสุด (กดผิด)'), findsNothing);
    await tester.tap(find.text('แสดงคำตอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อีกครั้ง'));
    await tester.pumpAndSettle();
    expect(current(), isNot(first));
    await tester.tap(find.byTooltip('เลิกทำการ์ดล่าสุด (กดผิด)'));
    await tester.pumpAndSettle();
    // Back on the same card, already turned over.
    expect(current(), first);
    expect(find.text('ดี'), findsOneWidget);
    expect(c.read(sessionProvider(vocabDeck)).answered, 0);
    await tester.tap(find.text('ดี'));
    await tester.pumpAndSettle();
    final log = StudyRepo(c.read(userDbProvider)).reviewRecords();
    expect(log.single.rating, Rating.good);
    // Keyboard Z undoes too.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();
    expect(StudyRepo(c.read(userDbProvider)).reviewRecords(), isEmpty);
  });

  testWidgets('flashcard look: hide parts from the in-session sheet', (
    tester,
  ) async {
    final c = await start(
      tester,
      settings: const AppSettings(includeKana: false),
    );
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('แสดงคำตอบ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('นาที'), findsWidgets);
    await tester.tap(find.byTooltip('หน้าการ์ด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('โหมดเต็มหน้าจอ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('เวลาบนปุ่มให้คะแนน'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('เวลาบนปุ่มให้คะแนน'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).shows(FlashPart.intervals), isFalse);
    expect(c.read(settingsProvider).flashFullscreen, isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('นาที'), findsNothing);
  });

  testWidgets('every theme renders all tabs', (tester) async {
    for (final theme in LcTokens.themes.keys) {
      await start(tester, settings: AppSettings(theme: theme));
      for (final tab in ['คลังคำ', 'สถิติ', 'หน้าหลัก']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('settings open and change a value', (tester) async {
    final c = await start(tester);
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เริ่มจากคานะ'));
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

  testWidgets('controller: B goes back, shoulder buttons switch tabs', (
    tester,
  ) async {
    await start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
    await tester.pumpAndSettle();
    expect(find.text('ค้นหา: คันจิ, คานะ, โรมาจิ หรือคำแปล'), findsOneWidget);
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
