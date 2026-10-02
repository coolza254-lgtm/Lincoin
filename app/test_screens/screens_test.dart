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
import 'package:lincoin/data/user_db.dart';
import 'package:lincoin/features/library/library_screen.dart';
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
  // The other font presets (settings preview and font screenshots).
  final files = Directory('assets/fonts').listSync().whereType<File>();
  for (final family in [
    'Sarabun',
    'KleeOne',
    'Trirong',
    'ShipporiMincho',
    'Mitr',
    'MPLUSRounded1c',
    'Kanit',
    'MPLUS1p',
  ]) {
    final loader = FontLoader(family);
    for (final f in files.where(
      (f) => f.uri.pathSegments.last.startsWith('$family-'),
    )) {
      loader.addFont(file(f.path));
    }
    await loader.load();
  }
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
    final settings = AppSettings(
      theme: theme,
      includeKana: false,
      grammarNewPerDay: 2,
    );
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
    await tester.scrollUntilVisible(find.text('JLPT N1'), 300);
    await snap('1b-levels');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('คลังคำ').last);
    await snap('1c-library');
    final chip = find.widgetWithText(ChoiceChip, 'กำลังจำ');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LibraryRow).first);
    await snap('1d-word-progress');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final all = find.widgetWithText(ChoiceChip, 'ทั้งหมด').last;
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.enterText(find.byType(TextField), 'taberu');
    await snap('1e-library-search');
    await tester.tap(find.text('หน้าหลัก').last);
    await tester.pumpAndSettle();
    for (final (tab, name) in [('สถิติ', '2-stats'), ('ฝึก', '4-practice')]) {
      await tester.tap(find.text(tab).last);
      await snap(name);
    }
    if (theme != 'matcha') return;
    // A practice round.
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
    // Flashcards (the default): front, then the turned-over back.
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    await snap('5f-flashcard-front');
    await tester.tap(find.text('แสดงคำตอบ'));
    await snap('5g-flashcard-back');
    await tester.tap(find.text('ดี'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    container
        .read(settingsProvider.notifier)
        .update((x) => x.copyWith(flashcards: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มเรียน').first);
    await tester.pumpAndSettle();
    var intro = false, choice = false, typed = false, feedback = false;
    var typedFeedback = false;
    for (
      var i = 0;
      i < 80 && !(intro && choice && typed && feedback && typedFeedback);
      i++
    ) {
      if (find.text('ต่อไป').evaluate().isNotEmpty) {
        final isTyped = find.text('พิมพ์คำอ่าน').evaluate().isNotEmpty;
        if (isTyped && !typedFeedback) {
          await snap('7b-typed-feedback');
          typedFeedback = true;
        } else if (!isTyped && !feedback) {
          await snap('8-feedback');
          feedback = true;
        }
        await tester.tap(find.text('ต่อไป'));
      } else if (find.text('จำแล้ว ไปต่อ').evaluate().isNotEmpty) {
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
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        break;
      }
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    // Grammar: lesson, cloze, feedback (below the level list).
    await tester.scrollUntilVisible(find.text('ดูทั้งหมด'), 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มเรียน').last);
    await tester.pumpAndSettle();
    await snap('10-grammar-lesson');
    await tester.tap(find.text('จำแล้ว ไปต่อ'));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 6 && find.text('เติมคำในช่องว่าง').evaluate().isEmpty;
      i++
    ) {
      if (find.text('ต่อไป').evaluate().isNotEmpty) {
        await tester.tap(find.text('ต่อไป'));
      } else if (find.text('จำแล้ว ไปต่อ').evaluate().isNotEmpty) {
        await tester.tap(find.text('จำแล้ว ไปต่อ'));
      }
      await tester.pumpAndSettle();
    }
    await snap('11-grammar-cloze');
    await tester.tap(find.byType(OutlinedButton).first);
    await snap('12-grammar-feedback');
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await snap('9-settings');
    await tester.scrollUntilVisible(find.text('ทันสมัย'), 300);
    await tester.ensureVisible(find.text('ทันสมัย'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 620));
    await snap('9a-settings-font');
    await tester.scrollUntilVisible(find.text('ปุ่มควบคุม'), 300);
    container
        .read(settingsProvider.notifier)
        .update((x) => x.copyWith(quickAnswerButtons: true));
    await snap('9b-settings-input');
    await tester.tap(find.text('ปุ่มควบคุม'));
    await snap('9c-controller-map');
    await tester.tap(find.text('ปิด').last);
    await tester.pumpAndSettle();
    // A drill question driven by a controller: focus ring and A/B/X/Y.
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pumpAndSettle();
    // R1 twice: home → library → practice.
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มฝึก 10 ข้อ'));
    await tester.pumpAndSettle();
    // Any controller key switches the app to showing focus rings.
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonSelect);
    await snap('4f-drill-controller');
  }

  for (final theme in ['matcha', 'sakura', 'mono', 'dark']) {
    testWidgets('screens $theme', (tester) => shoot(tester, theme));
  }
}
