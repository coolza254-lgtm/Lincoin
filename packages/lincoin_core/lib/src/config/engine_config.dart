import '../economy/challenge.dart';
import '../economy/rewards.dart';
import '../grading/grader.dart';
import '../srs/mastery.dart';
import '../srs/srs_config.dart';

/// Every tunable rule in one versioned bundle, stored as JSON in
/// `config_versions` so rules can change without an app update and old
/// results can be recomputed under the rules that produced them.
class EngineConfig {
  final int schemaVersion;
  final SrsConfig vocab;
  final SrsConfig grammar;
  final MasteryRule mastery;
  final GraderConfig grader;
  final RewardConfig rewards;
  final ChallengeConfig challenge;

  static const int currentSchemaVersion = 1;

  EngineConfig({
    this.schemaVersion = currentSchemaVersion,
    SrsConfig? vocab,
    SrsConfig? grammar,
    this.mastery = const MasteryRule(),
    this.grader = const GraderConfig(),
    this.rewards = const RewardConfig(),
    this.challenge = const ChallengeConfig(),
  })  : vocab = vocab ?? SrsConfig(),
        grammar = grammar ?? SrsConfig();

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'vocab': vocab.toJson(),
        'grammar': grammar.toJson(),
        'mastery': mastery.toJson(),
        'grader': grader.toJson(),
        'rewards': rewards.toJson(),
        'challenge': challenge.toJson(),
      };

  /// Missing sections fall back to defaults so older saved configs still load
  /// after new sections are added.
  factory EngineConfig.fromJson(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > currentSchemaVersion) {
      throw FormatException('Config schema $version is newer than supported '
          '$currentSchemaVersion');
    }
    Map<String, Object?>? section(String k) => json[k] as Map<String, Object?>?;
    T? parse<T>(String k, T Function(Map<String, Object?>) f) {
      final s = section(k);
      return s == null ? null : f(s);
    }

    return EngineConfig(
      schemaVersion: currentSchemaVersion,
      vocab: parse('vocab', SrsConfig.fromJson),
      grammar: parse('grammar', SrsConfig.fromJson),
      mastery: parse('mastery', MasteryRule.fromJson) ?? const MasteryRule(),
      grader: parse('grader', GraderConfig.fromJson) ?? const GraderConfig(),
      rewards: parse('rewards', RewardConfig.fromJson) ?? const RewardConfig(),
      challenge: parse('challenge', ChallengeConfig.fromJson) ??
          const ChallengeConfig(),
    );
  }
}
