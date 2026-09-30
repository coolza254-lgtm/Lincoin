import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/content_db.dart';
import 'services/content_store.dart';
import 'services/files.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  try {
    final paths = AppPaths(await getApplicationSupportDirectory())..ensure();
    await installBundledContent(ContentStore(paths.content), paths.tmp);
    final info = await PackageInfo.fromPlatform();
    final version = AppVersion(
      info.version,
      int.tryParse(info.buildNumber) ?? 0,
    );
    final container = ProviderContainer(
      overrides: [
        pathsProvider.overrideWithValue(paths),
        appVersionProvider.overrideWithValue(version),
      ],
    );
    // Open the database now so a failed migration shows the error screen.
    container.read(userDbProvider);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const LincoinApp(),
      ),
    );
  } on Object catch (e, st) {
    debugPrint('startup failed: $e\n$st');
    runApp(StartupError(message: '$e'));
  }
}

/// Copies the content.db shipped inside the APK into place on first run,
/// or when the app brings newer content than what is installed.
Future<void> installBundledContent(ContentStore store, Directory tmp) async {
  // Cheap check first: the version file is tiny, the database is not.
  try {
    final bundled = (await rootBundle.loadString('assets/content/version.txt'))
        .trim();
    final installed = store.installedVersion();
    if (installed != null && compareVersions(bundled, installed) <= 0) return;
  } on Object {
    // No version file (older build): fall back to opening the database.
  }
  final ByteData data;
  try {
    data = await rootBundle.load('assets/content/content.db');
  } on Object {
    return; // development build without bundled content
  }
  final f = File('${tmp.path}/bundled-content.db');
  await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
  try {
    final db = ContentDb.openFile(f.path);
    final bundled = db.info().version;
    db.close();
    final installed = store.installedVersion();
    if (installed == null || compareVersions(bundled, installed) > 0) {
      await store.install(f);
    }
  } finally {
    if (f.existsSync()) f.deleteSync();
  }
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('IBM Plex Sans Thai', 'OFL-IBMPlexSansThai.txt'),
      ('Zen Maru Gothic', 'OFL-ZenMaruGothic.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/licenses/$file');
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}

/// Shown when the app cannot start (e.g. data from a newer version).
class StartupError extends StatelessWidget {
  final String message;
  const StartupError({super.key, required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Lincoin เปิดไม่ได้',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'ข้อมูลการเรียนของคุณยังอยู่ครบ ลองอัปเดตแอปเป็นเวอร์ชันล่าสุด',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                message,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
