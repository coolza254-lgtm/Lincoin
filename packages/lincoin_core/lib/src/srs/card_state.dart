/// Our own card state, independent of the FSRS library's types so the
/// library can be swapped without touching storage or the app.
library;

enum CardStatus { newCard, learning, review, relearning }

/// Answer quality fed to the scheduler. Produced by the Grader, never chosen
/// by the learner.
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Rating(this.value);
  final int value;

  bool get isPass => this != Rating.again;

  static Rating fromValue(int value) =>
      Rating.values.firstWhere((r) => r.value == value,
          orElse: () => throw ArgumentError.value(value, 'value'));
}

class CardState {
  final CardStatus status;

  /// Index into learning/relearning steps; null in review/new.
  final int? step;
  final double? stability;
  final double? difficulty;

  /// Null only for new cards.
  final DateTime? due;
  final DateTime? lastReview;
  final Rating? lastRating;
  final int reps;
  final int lapses;

  const CardState({
    required this.status,
    this.step,
    this.stability,
    this.difficulty,
    this.due,
    this.lastReview,
    this.lastRating,
    this.reps = 0,
    this.lapses = 0,
  });

  static const CardState initial = CardState(status: CardStatus.newCard);

  bool get isNew => status == CardStatus.newCard;
  bool get inSteps =>
      status == CardStatus.learning || status == CardStatus.relearning;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'step': step,
        'stability': stability,
        'difficulty': difficulty,
        'due': due?.toIso8601String(),
        'lastReview': lastReview?.toIso8601String(),
        'lastRating': lastRating?.value,
        'reps': reps,
        'lapses': lapses,
      };

  factory CardState.fromJson(Map<String, Object?> json) => CardState(
        status: CardStatus.values.byName(json['status'] as String),
        step: (json['step'] as num?)?.toInt(),
        stability: (json['stability'] as num?)?.toDouble(),
        difficulty: (json['difficulty'] as num?)?.toDouble(),
        due: _date(json['due']),
        lastReview: _date(json['lastReview']),
        lastRating: json['lastRating'] == null
            ? null
            : Rating.fromValue((json['lastRating'] as num).toInt()),
        reps: (json['reps'] as num).toInt(),
        lapses: (json['lapses'] as num).toInt(),
      );

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();

  @override
  bool operator ==(Object other) =>
      other is CardState &&
      other.status == status &&
      other.step == step &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.due == due &&
      other.lastReview == lastReview &&
      other.lastRating == lastRating &&
      other.reps == reps &&
      other.lapses == lapses;

  @override
  int get hashCode => Object.hash(status, step, stability, difficulty, due,
      lastReview, lastRating, reps, lapses);

  @override
  String toString() => 'CardState(${toJson()})';
}
