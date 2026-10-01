import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../ui/input.dart';
import '../../data/catalog.dart';
import '../../data/user_db.dart';
import '../../services/study_service.dart';
import '../../state/providers.dart';

enum SessionPhase { intro, question, feedback, done }

class SessionState {
  final SessionPhase phase;
  final Question? question;
  final AnswerResult? result;

  /// Whether the last answer was right (feedback phase).
  final bool? correct;
  final String? typedAnswer;
  final int? chosenIndex;

  /// A valid synonym was typed; the learner may try again.
  final bool synonymHint;
  final bool hintShown;
  final bool guessing;
  final int answered;
  final int correctCount;
  final int coins;
  final int remaining;
  final SessionBonus? bonus;

  /// Learning steps due later than the session window.
  final int laterSteps;

  /// Flashcard turned over (answer side showing).
  final bool flipped;

  /// Flashcard: when each rating would bring the card back.
  final Map<Rating, Duration>? intervals;

  const SessionState({
    required this.phase,
    this.question,
    this.result,
    this.correct,
    this.typedAnswer,
    this.chosenIndex,
    this.synonymHint = false,
    this.hintShown = false,
    this.guessing = false,
    this.answered = 0,
    this.correctCount = 0,
    this.coins = 0,
    this.remaining = 0,
    this.bonus,
    this.laterSteps = 0,
    this.flipped = false,
    this.intervals,
  });

  SessionState copyWith({
    SessionPhase? phase,
    Question? question,
    AnswerResult? result,
    bool? correct,
    String? typedAnswer,
    int? chosenIndex,
    bool? synonymHint,
    bool? hintShown,
    bool? guessing,
    int? answered,
    int? correctCount,
    int? coins,
    int? remaining,
    SessionBonus? bonus,
    int? laterSteps,
    bool? flipped,
    Map<Rating, Duration>? intervals,
    bool clearAnswer = false,
  }) => SessionState(
    phase: phase ?? this.phase,
    question: question ?? this.question,
    result: clearAnswer ? null : (result ?? this.result),
    correct: clearAnswer ? null : (correct ?? this.correct),
    typedAnswer: clearAnswer ? null : (typedAnswer ?? this.typedAnswer),
    chosenIndex: clearAnswer ? null : (chosenIndex ?? this.chosenIndex),
    synonymHint: synonymHint ?? (clearAnswer ? false : this.synonymHint),
    hintShown: hintShown ?? (clearAnswer ? false : this.hintShown),
    guessing: guessing ?? (clearAnswer ? false : this.guessing),
    answered: answered ?? this.answered,
    correctCount: correctCount ?? this.correctCount,
    coins: coins ?? this.coins,
    remaining: remaining ?? this.remaining,
    bonus: bonus ?? this.bonus,
    laterSteps: laterSteps ?? this.laterSteps,
    flipped: flipped ?? (clearAnswer ? false : this.flipped),
    intervals: clearAnswer ? null : (intervals ?? this.intervals),
  );

  double get progress =>
      answered + remaining == 0 ? 0 : answered / (answered + remaining);
}

/// One vocabulary session: builds the queue, times answers, grades them
/// through the engines and records everything.
class SessionController extends Notifier<SessionState> {
  SessionController(this.deck);

  /// 'vocab' or 'grammar'.
  final String deck;

  late StudyService _svc;
  late SessionQueue _queue;
  late String _sessionId;
  final Stopwatch _answerTimer = Stopwatch();
  final Stopwatch _feedbackTimer = Stopwatch();
  int _activeMs = 0;

  /// Response time counts at most this much toward "active" study time.
  static const _activeCapMs = 60000;
  static const _feedbackCapMs = 30000;

  @override
  SessionState build() {
    final svc = ref.read(deckServiceProvider(deck));
    if (svc == null) return const SessionState(phase: SessionPhase.done);
    _svc = svc;
    final plan = svc.plan();
    _queue = SessionQueue(initial: svc.sessionOrder(plan));
    _sessionId = UserDb.newId();
    final now = svc.clock.nowUtc();
    svc.repo.startSession(
      _sessionId,
      'study',
      svc.deck,
      now,
      svc.studyDay(now),
    );
    ref.onDispose(_saveSession);
    return _advance(const SessionState(phase: SessionPhase.question));
  }

  SessionState _advance(SessionState s) {
    final now = _svc.clock.nowUtc();
    final id = _queue.next(now);
    if (id == null) return _finish(s);
    final q = _svc.question(id);
    _answerTimer
      ..reset()
      ..start();
    return s.copyWith(
      phase: q.needsIntro ? SessionPhase.intro : SessionPhase.question,
      question: q,
      remaining: _queue.length + 1,
      clearAnswer: true,
    );
  }

  SessionState _finish(SessionState s) {
    _answerTimer.stop();
    final bonus = _svc.finishSession(answeredAny: s.answered > 0);
    ref.read(challengeServiceProvider)?.settleWeekly();
    _saveSession(ended: true);
    ref.read(dataVersionProvider.notifier).bump();
    return s.copyWith(
      phase: SessionPhase.done,
      bonus: bonus,
      coins: s.coins + bonus.total,
      remaining: 0,
      laterSteps: _queue.laterSteps(_svc.clock.nowUtc()),
    );
  }

  void _saveSession({bool ended = false}) {
    try {
      _svc.repo.updateSession(
        _sessionId,
        activeMs: _activeMs,
        answered: state.answered,
        endedAt: ended ? _svc.clock.nowUtc() : null,
        summary: ended
            ? {
                'answered': state.answered,
                'correct': state.correctCount,
                'coins': state.coins,
              }
            : null,
      );
    } on Object {
      // The database may already be closed (e.g. after a restore).
    }
  }

  /// Leaves the introduction; the question comes after a few other cards.
  void finishIntro() {
    final q = state.question!;
    _svc.introduce(q);
    _activeMs += _answerTimer.elapsedMilliseconds.clamp(0, _activeCapMs);
    _queue.afterIntro(q.cardId, _svc.clock.nowUtc());
    state = _advance(state);
  }

  /// Turns a flashcard over.
  void flip() {
    if (state.phase != SessionPhase.question || state.flipped) return;
    final q = state.question!;
    if (!q.isFlashcard) return;
    Feel.selection();
    state = state.copyWith(flipped: true, intervals: _svc.intervals(q));
    final say = switch (q.item) {
      WordStudy(:final word) => word.reading,
      KanaStudy(:final kana) => kana.char,
      _ => null,
    };
    if (say != null && ref.read(settingsProvider).autoPlayAudio) {
      ref.read(ttsProvider).speak(say).ignore();
    }
  }

  /// The learner's own rating of a turned-over flashcard; the next card
  /// follows straight away, as in Anki.
  void rate(Rating rating) {
    final q = state.question;
    if (state.phase != SessionPhase.question ||
        q == null ||
        !q.isFlashcard ||
        !state.flipped) {
      return;
    }
    if (_svc.stored(q.cardId) == null) _svc.introduce(q);
    _answerTimer.stop();
    final ms = _answerTimer.elapsedMilliseconds;
    _activeMs += ms.clamp(0, _activeCapMs);
    final ok = rating.isPass;
    final result = _svc.answer(
      q,
      AnswerEvent(isCorrect: ok, responseMs: ms),
      sessionId: _sessionId,
      answerRaw: rating.name,
      selfRating: rating,
    );
    if (result.outcome.after.inSteps) {
      _queue.requeue(q.cardId, result.outcome.after.due!);
    }
    ok ? Feel.light() : Feel.medium();
    state = _advance(
      state.copyWith(
        answered: state.answered + 1,
        correctCount: state.correctCount + (ok ? 1 : 0),
        coins: state.coins + result.coinTotal,
        result: result,
      ),
    );
  }

  void toggleGuess() => state = state.copyWith(guessing: !state.guessing);

  /// Shows the first kana of the answer (typed questions); grades as Hard
  /// at best.
  void showHint() => state = state.copyWith(hintShown: true);

  void chooseOption(int index) {
    final q = state.question!;
    _grade(
      index == q.choices!.correctIndex,
      chosen: index,
      raw: q.choices!.options[index],
    );
  }

  void submitTyped(String input) {
    if (input.trim().isEmpty) return;
    final check = _svc.checkTyped(state.question!, input);
    if (check == AnswerCheck.synonym && !state.synonymHint) {
      state = state.copyWith(synonymHint: true);
      return;
    }
    _grade(check == AnswerCheck.correct, typed: input, raw: input);
  }

  void dontKnow() => _grade(false, gaveUp: true);

  void _grade(
    bool correct, {
    int? chosen,
    String? typed,
    String? raw,
    bool gaveUp = false,
  }) {
    if (state.phase != SessionPhase.question) return;
    _answerTimer.stop();
    final ms = _answerTimer.elapsedMilliseconds;
    _activeMs += ms.clamp(0, _activeCapMs);
    final q = state.question!;
    final result = _svc.answer(
      q,
      AnswerEvent(
        isCorrect: correct,
        responseMs: ms,
        usedHint: state.hintShown,
        markedGuess: state.guessing,
        gaveUp: gaveUp,
      ),
      sessionId: _sessionId,
      answerRaw: raw,
    );
    if (result.outcome.after.inSteps) {
      _queue.requeue(q.cardId, result.outcome.after.due!);
    }
    correct ? Feel.light() : Feel.medium();
    _feedbackTimer
      ..reset()
      ..start();
    state = state.copyWith(
      phase: SessionPhase.feedback,
      result: result,
      correct: correct,
      chosenIndex: chosen,
      typedAnswer: typed,
      answered: state.answered + 1,
      correctCount: state.correctCount + (correct ? 1 : 0),
      coins: state.coins + result.coinTotal,
      remaining: _queue.length,
    );
    // Screens behind the session refresh once it ends, not per answer.
  }

  void next() {
    _feedbackTimer.stop();
    _activeMs += _feedbackTimer.elapsedMilliseconds.clamp(0, _feedbackCapMs);
    state = _advance(state);
  }

  /// Ends early (progress so far is already saved).
  void quit() {
    if (state.phase != SessionPhase.done) _saveSession(ended: true);
  }
}

final sessionProvider = NotifierProvider.autoDispose
    .family<SessionController, SessionState, String>(SessionController.new);
