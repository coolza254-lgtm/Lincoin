import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../ui/input.dart';
import '../../data/catalog.dart';
import '../../data/user_db.dart';
import '../../services/challenge_service.dart';
import '../../services/practice_service.dart';
import '../../services/study_service.dart';

enum DrillPhase { question, feedback, done }

/// What kind of round to play.
class DrillConfig {
  final ChallengeRecord? challenge;
  final int count;
  final Duration? timeLimit;
  final bool stopOnWrong;
  final bool weakOnly;
  final bool choiceOnly;

  const DrillConfig._({
    this.challenge,
    required this.count,
    this.timeLimit,
    this.stopOnWrong = false,
    this.weakOnly = false,
    this.choiceOnly = false,
  });

  /// Unlimited practice, 10 questions per round.
  const DrillConfig.practice() : this._(count: 10);

  factory DrillConfig.challenge(ChallengeRecord c) => switch (c.type) {
    ChallengeType.speed => DrillConfig._(
      challenge: c,
      count: 500,
      timeLimit: const Duration(seconds: 60),
      choiceOnly: true,
    ),
    ChallengeType.streak => DrillConfig._(
      challenge: c,
      count: ChallengeType.streak.maxScore,
      stopOnWrong: true,
      choiceOnly: true,
    ),
    _ => DrillConfig._(challenge: c, count: 10, weakOnly: true),
  };

  bool get isChallenge => challenge != null;
  String get mode => isChallenge ? 'challenge' : 'practice';
}

/// Runs one practice or challenge round. Plain ChangeNotifier: the screen
/// owns it for the round's lifetime.
class DrillController extends ChangeNotifier {
  final PracticeService practice;
  final ChallengeService? challenges;
  final DrillConfig config;
  final math.Random _rnd;
  final void Function() onDataChanged;

  final String sessionId = UserDb.newId();
  late final List<PracticeItem> _items;
  final Stopwatch _answerTimer = Stopwatch();
  final Stopwatch _roundTimer = Stopwatch();
  Timer? _ticker;
  Timer? _autoNext;
  int _activeMs = 0;
  bool _disposed = false;

  DrillPhase phase = DrillPhase.question;
  int index = 0;
  Question? question;
  PracticeItem? current;
  int answered = 0;
  int correct = 0;
  int combo = 0;
  int bestCombo = 0;
  int coins = 0;
  int lastCoins = 0;
  bool? lastCorrect;
  int? chosen;
  String? typed;
  bool synonymHint = false;
  ChallengeRecord? result;

  DrillController({
    required this.practice,
    required this.config,
    required this.onDataChanged,
    this.challenges,
    math.Random? random,
  }) : _rnd = random ?? math.Random() {
    final pool = practice.pool();
    // Timed/streak rounds reuse items if the pool is small.
    final wanted = math.min(config.count, pool.length);
    _items = practice.pick(pool, wanted, _rnd, weakOnly: config.weakOnly);
    final study = practice.study;
    final now = study.clock.nowUtc();
    study.repo.startSession(
      sessionId,
      config.mode,
      vocabDeck,
      now,
      study.studyDay(now),
    );
    _roundTimer.start();
    // The screen animates the clock itself; this only ends the round.
    if (config.timeLimit != null) _ticker = Timer(config.timeLimit!, _finish);
    _next();
  }

  int get total =>
      config.timeLimit != null || config.stopOnWrong ? 0 : _items.length;

  /// Share of the time limit already used (0 without a limit).
  double get elapsedFraction {
    final limit = config.timeLimit;
    if (limit == null) return 0;
    return (_roundTimer.elapsedMilliseconds / limit.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Duration get remaining {
    final limit = config.timeLimit;
    if (limit == null) return Duration.zero;
    final left = limit - _roundTimer.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final limit = config.timeLimit;
    if (limit != null) {
      return _roundTimer.elapsedMilliseconds / limit.inMilliseconds;
    }
    if (config.stopOnWrong) return correct / config.count;
    return _items.isEmpty ? 1 : answered / _items.length;
  }

  /// Score for challenges: correct answers.
  int get score => correct;

  bool get isEmpty => _items.isEmpty;

  void _next() {
    if (phase == DrillPhase.done) return;
    final endless = config.timeLimit != null || config.stopOnWrong;
    if (!endless && index >= _items.length) {
      _finish();
      return;
    }
    if (_items.isEmpty) {
      _finish();
      return;
    }
    if (endless && index > 0 && index % _items.length == 0) {
      _items.shuffle(_rnd);
    }
    current = _items[index % _items.length];
    index++;
    question = practice.question(current!, _rnd, choiceOnly: config.choiceOnly);
    phase = DrillPhase.question;
    lastCorrect = null;
    chosen = null;
    typed = null;
    synonymHint = false;
    _answerTimer
      ..reset()
      ..start();
    notifyListeners();
  }

  void choose(int i) {
    if (phase != DrillPhase.question) return;
    chosen = i;
    _answer(i == question!.choices!.correctIndex);
  }

  void submitTyped(String input) {
    if (phase != DrillPhase.question || input.trim().isEmpty) return;
    final check = practice.checkTyped(question!, input);
    if (check == AnswerCheck.synonym && !synonymHint) {
      synonymHint = true;
      notifyListeners();
      return;
    }
    typed = input;
    _answer(check == AnswerCheck.correct);
  }

  void dontKnow() {
    if (phase != DrillPhase.question) return;
    _answer(false);
  }

  void _answer(bool ok) {
    _answerTimer.stop();
    final ms = _answerTimer.elapsedMilliseconds;
    _activeMs += ms.clamp(0, 60000);
    answered++;
    if (ok) {
      correct++;
      combo++;
      bestCombo = math.max(bestCombo, combo);
      Feel.light();
    } else {
      combo = 0;
      Feel.medium();
    }
    final a = practice.record(
      q: question!,
      correct: ok,
      responseMs: ms,
      mode: config.mode,
      sessionId: sessionId,
      weak: current!.weak,
      combo: combo,
    );
    lastCoins = a.coinTotal;
    coins += a.coinTotal;
    lastCorrect = ok;
    phase = DrillPhase.feedback;
    notifyListeners();

    if (config.stopOnWrong && !ok) {
      _autoNext = Timer(const Duration(milliseconds: 1200), _finish);
      return;
    }
    if (config.isChallenge) {
      // Challenges keep moving; practice waits for "ต่อไป".
      final delay = config.timeLimit != null ? 350 : 900;
      _autoNext = Timer(Duration(milliseconds: delay), () {
        if (!_disposed) _next();
      });
    }
  }

  /// Practice: continue after reading the feedback.
  void next() {
    if (phase == DrillPhase.feedback) _next();
  }

  void _finish() {
    if (phase == DrillPhase.done || _disposed) return;
    _ticker?.cancel();
    _autoNext?.cancel();
    _answerTimer.stop();
    _roundTimer.stop();
    phase = DrillPhase.done;
    final c = config.challenge;
    if (c != null && challenges != null) {
      result = challenges!.finish(c.id, score);
    }
    _saveSession(ended: true);
    onDataChanged();
    notifyListeners();
  }

  /// Ends a practice round early (answers so far are kept).
  void stop() => _finish();

  void _saveSession({bool ended = false}) {
    final study = practice.study;
    try {
      study.repo.updateSession(
        sessionId,
        activeMs: _activeMs,
        answered: answered,
        endedAt: ended ? study.clock.nowUtc() : null,
        summary: ended
            ? {'answered': answered, 'correct': correct, 'coins': coins}
            : null,
      );
    } on Object {
      // Database closed (restore) — nothing to save.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _autoNext?.cancel();
    if (phase != DrillPhase.done) {
      // Leaving a challenge early forfeits it.
      final c = config.challenge;
      if (c != null) challenges?.forfeit(c.id);
      _saveSession(ended: true);
      // Not during widget-tree teardown.
      Future.microtask(onDataChanged);
    }
    super.dispose();
  }
}
