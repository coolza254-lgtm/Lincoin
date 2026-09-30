import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/catalog.dart';
import '../data/content_db.dart';
import '../data/settings_repo.dart';
import '../data/shop_repo.dart';
import '../data/study_repo.dart';
import '../data/user_db.dart';
import '../services/backup_service.dart';
import '../services/challenge_service.dart';
import '../services/practice_service.dart';
import '../services/content_store.dart';
import '../services/files.dart';
import '../services/stats_service.dart';
import '../services/study_service.dart';
import '../services/tts.dart';
import '../services/update_service.dart';

/// Installed app version, from the platform (overridden in main).
class AppVersion {
  final String name;
  final int code;
  const AppVersion(this.name, this.code);
}

// ---- values set up in main() ----
final pathsProvider = Provider<AppPaths>((_) => throw UnimplementedError());
final appVersionProvider = Provider<AppVersion>(
  (_) => const AppVersion('dev', 0),
);
final clockProvider = Provider<Clock>((_) => const Clock());
final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});
final ttsProvider = Provider<Tts>((ref) {
  final t = Tts();
  ref.onDispose(t.dispose);
  return t;
});

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(pathsProvider).backups),
);
final contentStoreProvider = Provider(
  (ref) => ContentStore(ref.watch(pathsProvider).content),
);

/// The open user database. Replaced when a backup is restored.
class UserDbHolder extends Notifier<UserDb> {
  UserDb? _db;

  @override
  UserDb build() {
    ref.onDispose(() => _db?.close());
    return _open();
  }

  UserDb _open() {
    final paths = ref.read(pathsProvider);
    final backups = ref.read(backupServiceProvider);
    return _db = UserDb.open(
      paths.userDb,
      beforeMigrate: (from) =>
          backups.backupFile(paths.userDb, 'before_migrate'),
    );
  }

  /// Restores [path] over the live database. A backup is taken first.
  List<String> restore(String path) {
    final problems = BackupService.validate(path);
    if (problems.isNotEmpty) return problems;
    ref.read(backupServiceProvider).backup(state, 'before_restore');
    _db?.close();
    _db = null;
    BackupService.replaceDatabase(path, ref.read(pathsProvider).userDb);
    state = _open();
    return const [];
  }
}

final userDbProvider = NotifierProvider<UserDbHolder, UserDb>(UserDbHolder.new);

/// Loaded content, or null when none is installed yet.
class CatalogHolder extends Notifier<Catalog?> {
  ContentDb? _db;

  @override
  Catalog? build() {
    ref.onDispose(() => _db?.close());
    return _open();
  }

  Catalog? _open() {
    _db?.close();
    _db = null;
    final store = ref.read(contentStoreProvider);
    if (!store.current.existsSync()) return null;
    _db = ContentDb.openFile(store.current.path);
    return Catalog.load(_db!);
  }

  /// Re-reads content.db after it was replaced, and moves cards of items
  /// that changed id (deprecations).
  void reload() {
    final c = _open();
    if (c != null) {
      StudyRepo(ref.read(userDbProvider))
          .applyDeprecations(c.db.deprecations());
    }
    state = c;
    ref.read(dataVersionProvider.notifier).bump();
  }
}

final catalogProvider = NotifierProvider<CatalogHolder, Catalog?>(
  CatalogHolder.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => SettingsRepo(ref.watch(userDbProvider)).load();

  void update(AppSettings Function(AppSettings) f) {
    final next = f(state);
    SettingsRepo(ref.read(userDbProvider))
        .save(next, ref.read(clockProvider).nowUtc());
    state = next;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Bumped after any write, so read models recompute.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

/// Study rules for the current settings; null without content.
final studyServiceProvider = Provider<StudyService?>((ref) {
  final catalog = ref.watch(catalogProvider);
  if (catalog == null) return null;
  return StudyService(
    db: ref.watch(userDbProvider),
    catalog: catalog,
    settings: ref.watch(settingsProvider),
    clock: ref.watch(clockProvider),
  );
});

final todayPlanProvider = Provider<TodayPlan?>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(studyServiceProvider)?.plan();
});

final coverageProvider = Provider<Map<String, double>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(studyServiceProvider)?.coverage() ?? const {};
});

final balanceProvider = Provider<int>((ref) {
  ref.watch(dataVersionProvider);
  return LedgerRepo(ref.watch(userDbProvider)).balance();
});

final statsProvider = Provider<StatsData?>((ref) {
  ref.watch(dataVersionProvider);
  final s = ref.watch(studyServiceProvider);
  return s == null ? null : StatsService(s).compute();
});

final shopRepoProvider = Provider((ref) => ShopRepo(ref.watch(userDbProvider)));

final updateServiceProvider = Provider(
  (ref) => UpdateService(ref.watch(httpClientProvider)),
);

final practiceServiceProvider = Provider<PracticeService?>((ref) {
  final s = ref.watch(studyServiceProvider);
  return s == null ? null : PracticeService(s);
});

final challengeServiceProvider = Provider<ChallengeService?>((ref) {
  final s = ref.watch(studyServiceProvider);
  return s == null ? null : ChallengeService(s);
});
