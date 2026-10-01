import 'package:lincoin_core/lincoin_core.dart';

import '../ui/tokens.g.dart';
import 'user_db.dart';

enum FuriganaMode { always, hideMastered, never }

/// All user settings with defaults and valid ranges (docs/03-database.md).
class AppSettings {
  final String theme;
  final double vocabRetention;
  final int vocabNewPerDay;
  final double grammarRetention;
  final int grammarNewPerDay;
  final bool includeKana;
  final FuriganaMode furigana;
  final int dayStartHour;
  final bool onlineUpdateCheck;
  final bool reduceMotion;
  final bool autoPlayAudio;
  final bool haptics;
  final bool controller;
  final bool swapAB;
  final bool quickAnswerButtons;

  /// Vocabulary reviews as self-rated flashcards (Anki/Kaishi style)
  /// instead of quizzes.
  final bool flashcards;

  const AppSettings({
    this.theme = LcTokens.defaultTheme,
    this.vocabRetention = 0.90,
    this.vocabNewPerDay = 10,
    this.grammarRetention = 0.90,
    this.grammarNewPerDay = 2,
    this.includeKana = true,
    this.furigana = FuriganaMode.always,
    this.dayStartHour = 4,
    this.onlineUpdateCheck = true,
    this.reduceMotion = false,
    this.autoPlayAudio = false,
    this.haptics = true,
    this.controller = true,
    this.swapAB = false,
    this.quickAnswerButtons = false,
    this.flashcards = true,
  });

  /// Animations on (the setting is stored as its opposite, reduce_motion).
  bool get animations => !reduceMotion;

  static const newPerDayMax = 50;
  static const grammarNewPerDayMax = 10;

  AppSettings copyWith({
    String? theme,
    double? vocabRetention,
    int? vocabNewPerDay,
    double? grammarRetention,
    int? grammarNewPerDay,
    bool? includeKana,
    FuriganaMode? furigana,
    int? dayStartHour,
    bool? onlineUpdateCheck,
    bool? reduceMotion,
    bool? autoPlayAudio,
    bool? haptics,
    bool? controller,
    bool? swapAB,
    bool? quickAnswerButtons,
    bool? flashcards,
  }) => AppSettings(
    theme: theme ?? this.theme,
    vocabRetention: vocabRetention ?? this.vocabRetention,
    vocabNewPerDay: vocabNewPerDay ?? this.vocabNewPerDay,
    grammarRetention: grammarRetention ?? this.grammarRetention,
    grammarNewPerDay: grammarNewPerDay ?? this.grammarNewPerDay,
    includeKana: includeKana ?? this.includeKana,
    furigana: furigana ?? this.furigana,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    onlineUpdateCheck: onlineUpdateCheck ?? this.onlineUpdateCheck,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
    haptics: haptics ?? this.haptics,
    controller: controller ?? this.controller,
    swapAB: swapAB ?? this.swapAB,
    quickAnswerButtons: quickAnswerButtons ?? this.quickAnswerButtons,
    flashcards: flashcards ?? this.flashcards,
  );

  Map<String, String> toMap() => {
    'theme': theme,
    'vocab.desired_retention': vocabRetention.toStringAsFixed(2),
    'vocab.new_per_day': '$vocabNewPerDay',
    'grammar.desired_retention': grammarRetention.toStringAsFixed(2),
    'grammar.new_per_day': '$grammarNewPerDay',
    'vocab.include_kana': '$includeKana',
    'furigana': furigana.name,
    'day_start_hour': '$dayStartHour',
    'update.online_check': '$onlineUpdateCheck',
    'reduce_motion': '$reduceMotion',
    'audio.autoplay': '$autoPlayAudio',
    'input.haptics': '$haptics',
    'input.controller': '$controller',
    'input.swap_ab': '$swapAB',
    'input.quick_answer': '$quickAnswerButtons',
    'vocab.flashcards': '$flashcards',
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
      grammarRetention: dbl(
        'grammar.desired_retention',
        d.grammarRetention,
        SrsConfig.minRetention,
        SrsConfig.maxRetention,
      ),
      grammarNewPerDay: integer(
        'grammar.new_per_day',
        d.grammarNewPerDay,
        0,
        grammarNewPerDayMax,
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
      haptics: b('input.haptics', d.haptics),
      controller: b('input.controller', d.controller),
      swapAB: b('input.swap_ab', d.swapAB),
      quickAnswerButtons: b('input.quick_answer', d.quickAnswerButtons),
      flashcards: b('vocab.flashcards', d.flashcards),
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
