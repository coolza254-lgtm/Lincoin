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
import '../services/library_service.dart';
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

/// Study rules for one deck ('vocab' / 'grammar'), or one level of it
/// ([studyKey]); null without content.
final deckServiceProvider = Provider.family<StudyService?, String>((ref, key) {
  final catalog = ref.watch(catalogProvider);
  if (catalog == null) return null;
  final (deck, level) = parseStudyKey(key);
  return StudyService(
    level: level,
    db: ref.watch(userDbProvider),
    catalog: catalog,
    settings: ref.watch(settingsProvider),
    clock: ref.watch(clockProvider),
    deck: deck,
  );
});

/// The vocabulary deck (also used for practice, challenges and the shop).
final studyServiceProvider = Provider<StudyService?>(
  (ref) => ref.watch(deckServiceProvider(vocabDeck)),
);

final todayPlanProvider = Provider.family<TodayPlan?, String>((ref, deck) {
  ref.watch(dataVersionProvider);
  return ref.watch(deckServiceProvider(deck))?.plan();
});

final coverageProvider = Provider.family<Map<String, double>, String>((
  ref,
  deck,
) {
  ref.watch(dataVersionProvider);
  return ref.watch(deckServiceProvider(deck))?.coverage() ?? const {};
});

/// Words (or kana) started and total per vocabulary level.
final levelProgressProvider = Provider<Map<String, ({int learned, int total})>>(
  (ref) {
    ref.watch(dataVersionProvider);
    final svc = ref.watch(deckServiceProvider(vocabDeck));
    if (svc == null) return const {};
    final started = <String, int>{};
    for (final c in svc.repo.cards(deck: vocabDeck).values) {
      if (c.state.isNew || c.id.endsWith('#recall')) continue;
      final level = svc.catalog.byId[c.itemId]?.level;
      if (level != null) started[level] = (started[level] ?? 0) + 1;
    }
    final totals = svc.catalog.itemsPerLevel(vocabDeck);
    return {
      for (final l in vocabLevels)
        l: (learned: started[l] ?? 0, total: totals[l] ?? 0),
    };
  },
);

/// The word library (search and per-word progress).
final libraryProvider = Provider<LibraryService?>((ref) {
  ref.watch(dataVersionProvider);
  final s = ref.watch(deckServiceProvider(vocabDeck));
  return s == null ? null : LibraryService(s);
});

/// Cards of a deck (or level, see [studyKey]) answered today.
final todayDoneProvider = Provider.family<int, String>((ref, key) {
  ref.watch(dataVersionProvider);
  return ref.watch(deckServiceProvider(key))?.answeredToday() ?? 0;
});

final statsProvider = Provider.family<StatsData?, String>((ref, deck) {
  ref.watch(dataVersionProvider);
  final s = ref.watch(deckServiceProvider(deck));
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

/// What was done today (home screen summary).
class TodaySummary {
  final int reviews;
  final int practice;
  final int coins;
  const TodaySummary(this.reviews, this.practice, this.coins);
  bool get any => reviews > 0 || practice > 0;
}

final todaySummaryProvider = Provider<TodaySummary>((ref) {
  ref.watch(dataVersionProvider);
  final svc = ref.watch(studyServiceProvider);
  if (svc == null) return const TodaySummary(0, 0, 0);
  final day = svc.studyDay();
  int count(String sql) =>
      (svc.db.db.select(sql, [day]).first.columnAt(0) as num?)?.toInt() ?? 0;
  return TodaySummary(
    count('SELECT count(*) FROM review_log WHERE study_day = ?'),
    count('SELECT count(*) FROM practice_log WHERE study_day = ?'),
    count(
      'SELECT COALESCE(SUM(delta), 0) FROM coin_ledger '
      'WHERE study_day = ? AND delta > 0',
    ),
  );
});

/// Days in a row with any study or practice. While today is still open the
/// streak counts up to yesterday; [today] says whether today already counts.
class Streak {
  final int days;
  final bool today;
  const Streak(this.days, this.today);
}

final streakProvider = Provider<Streak>((ref) {
  ref.watch(dataVersionProvider);
  final svc = ref.watch(studyServiceProvider);
  if (svc == null) return const Streak(0, false);
  final today = svc.studyDay();
  final from = today - 800;
  final days = {
    for (final r in svc.db.db.select(
      'SELECT study_day FROM review_log WHERE study_day >= ? '
      'UNION SELECT study_day FROM practice_log WHERE study_day >= ?',
      [from, from],
    ))
      r.columnAt(0) as int,
  };
  final studiedToday = days.contains(today);
  var d = studiedToday ? today : today - 1;
  var n = 0;
  while (days.contains(d)) {
    n++;
    d--;
  }
  return Streak(n, studiedToday);
});
