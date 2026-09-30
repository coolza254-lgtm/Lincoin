import 'package:lincoin_core/lincoin_core.dart';

import '../ui/tokens.g.dart';
import 'user_db.dart';

enum FuriganaMode { always, hideMastered, never }

/// All user settings with defaults and valid ranges (docs/03-database.md).
class AppSettings {
  final String theme;
  final double vocabRetention;
  final int vocabNewPerDay;
  final bool includeKana;
  final FuriganaMode furigana;
  final int dayStartHour;
  final bool onlineUpdateCheck;
  final bool reduceMotion;
  final bool autoPlayAudio;

  const AppSettings({
    this.theme = LcTokens.defaultTheme,
    this.vocabRetention = 0.90,
    this.vocabNewPerDay = 10,
    this.includeKana = true,
    this.furigana = FuriganaMode.always,
    this.dayStartHour = 4,
    this.onlineUpdateCheck = true,
    this.reduceMotion = false,
    this.autoPlayAudio = false,
  });

  static const newPerDayMax = 50;

  AppSettings copyWith({
    String? theme,
    double? vocabRetention,
    int? vocabNewPerDay,
    bool? includeKana,
    FuriganaMode? furigana,
    int? dayStartHour,
    bool? onlineUpdateCheck,
    bool? reduceMotion,
    bool? autoPlayAudio,
  }) => AppSettings(
    theme: theme ?? this.theme,
    vocabRetention: vocabRetention ?? this.vocabRetention,
    vocabNewPerDay: vocabNewPerDay ?? this.vocabNewPerDay,
    includeKana: includeKana ?? this.includeKana,
    furigana: furigana ?? this.furigana,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    onlineUpdateCheck: onlineUpdateCheck ?? this.onlineUpdateCheck,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
  );

  Map<String, String> toMap() => {
    'theme': theme,
    'vocab.desired_retention': vocabRetention.toStringAsFixed(2),
    'vocab.new_per_day': '$vocabNewPerDay',
    'vocab.include_kana': '$includeKana',
    'furigana': furigana.name,
    'day_start_hour': '$dayStartHour',
    'update.online_check': '$onlineUpdateCheck',
    'reduce_motion': '$reduceMotion',
    'audio.autoplay': '$autoPlayAudio',
  };

  /// Unknown or out-of-range values fall back to defaults, so a setting
  /// removed or renamed in a later version never breaks startup.
  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    double dbl(String k, double def, double lo, double hi) {
      final v = double.tryParse(m[k] ?? '');
      return v == null || v < lo || v > hi ? def : v;
    }

    int integer(String k, int def, int lo, int hi) {
      final v = int.tryParse(m[k] ?? '');
      return v == null || v < lo || v > hi ? def : v;
    }

    bool b(String k, bool def) => switch (m[k]) {
      'true' => true,
      'false' => false,
      _ => def,
    };
    final theme = m['theme'];
    return AppSettings(
      theme: LcTokens.themes.containsKey(theme) ? theme! : d.theme,
      vocabRetention: dbl(
        'vocab.desired_retention',
        d.vocabRetention,
        SrsConfig.minRetention,
        SrsConfig.maxRetention,
      ),
      vocabNewPerDay: integer(
        'vocab.new_per_day',
        d.vocabNewPerDay,
        0,
        newPerDayMax,
      ),
      includeKana: b('vocab.include_kana', d.includeKana),
      furigana:
          FuriganaMode.values
              .where((f) => f.name == m['furigana'])
              .firstOrNull ??
          d.furigana,
      dayStartHour: integer('day_start_hour', d.dayStartHour, 0, 6),
      onlineUpdateCheck: b('update.online_check', d.onlineUpdateCheck),
      reduceMotion: b('reduce_motion', d.reduceMotion),
      autoPlayAudio: b('audio.autoplay', d.autoPlayAudio),
    );
  }
}

class SettingsRepo {
  final UserDb u;
  SettingsRepo(this.u);

  AppSettings load() => AppSettings.fromMap({
    for (final r in u.db.select('SELECT key, value FROM settings'))
      r['key'] as String: r['value'] as String,
  });

  void save(AppSettings s, DateTime now) {
    u.tx(() {
      s.toMap().forEach(
        (k, v) => u.db.execute(
          'INSERT OR REPLACE INTO settings(key, value, updated_at) '
          'VALUES (?, ?, ?)',
          [k, v, now.millisecondsSinceEpoch],
        ),
      );
    });
  }
}
