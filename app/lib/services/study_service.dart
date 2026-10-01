import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/content_db.dart';
import '../data/settings_repo.dart';
import '../data/study_repo.dart';
import '../data/user_db.dart';

/// Wall clock and time zone, injectable for tests.
class Clock {
  final DateTime Function() _now;
  final int Function()? _tz;
  const Clock([this._now = DateTime.now, this._tz]);

  DateTime nowUtc() => _now().toUtc();
  int tzOffsetMinutes() => _tz?.call() ?? _now().timeZoneOffset.inMinutes;
}

/// Today's work for the home screen.
class TodayPlan {
  final StudyQueue queue;
  final int studyDay;
  final int newRemainingToday;

  /// Rough minutes to finish, from the learner's own answer times.
  final int estimatedMinutes;

  const TodayPlan(
    this.queue,
    this.studyDay,
    this.newRemainingToday,
    this.estimatedMinutes,
  );

  int get dueCount => queue.dueCount;
  int get newCount => queue.newCards.length;
  bool get isEmpty => dueCount == 0 && newCount == 0;
}

/// A question ready to show.
class Question {
  final String cardId;
  final StudyItem item;
  final Facet facet;

  /// Stored in review_log; the grader keeps a response-time median per type.
  final String type;
  final ChoiceSet? choices;

  /// First time this card is seen: show the introduction first.
  final bool needsIntro;

  /// Grammar cloze: the sentence asked about.
  final GrammarExample? example;

  const Question({
    required this.cardId,
    required this.item,
    required this.facet,
    required this.type,
    this.choices,
    this.needsIntro = false,
    this.example,
  });

  bool get isTyped => choices == null && !isFlashcard;

  /// Self-rated flashcard: flip, then Again/Hard/Good/Easy.
  bool get isFlashcard => form == QuestionForm.flashcard;

  QuestionForm get form => QuestionForm.fromType(type);
}

/// How a question is asked; the name before the dot in [Question.type].
enum QuestionForm {
  /// Japanese word → choose its Thai meaning ("recog.choice").
  meaningChoice,

  /// Thai meaning → type the reading ("recall.type").
  readingType,

  /// Thai meaning → choose the Japanese word ("reverse.choice", practice).
  wordChoice,

  /// Kana → type romaji ("kana.type").
  kanaType,

  /// Kana → choose romaji ("kana.choice", practice).
  kanaChoice,

  /// Grammar: choose what fills the blank ("cloze.choice").
  cloze,

  /// Flashcard, rated by the learner: word → meaning ("recog.flash") or
  /// meaning → word ("recall.flash").
  flashcard;

  static QuestionForm fromType(String type) => switch (type) {
    'recall.type' => readingType,
    'reverse.choice' => wordChoice,
    'kana.type' => kanaType,
    'kana.choice' => kanaChoice,
    'cloze.choice' => cloze,
    'recog.flash' || 'recall.flash' || 'kana.flash' => flashcard,
    _ => meaningChoice,
  };

  /// Options are Japanese text (shown in the Japanese font).
  bool get japaneseOptions => this == wordChoice || this == cloze;
}

enum AnswerCheck { correct, wrong, synonym }

class AnswerResult {
  final Rating rating;
  final ReviewOutcome outcome;
  final List<LedgerEntry> coins;
  final bool graduated;
  final bool mastered;
  final bool leech;

  const AnswerResult(
    this.rating,
    this.outcome,
    this.coins, {
    this.graduated = false,
    this.mastered = false,
    this.leech = false,
  });

  int get coinTotal => coins.fold(0, (s, e) => s + e.delta);
}

/// Bonuses paid when a session ends.
class SessionBonus {
  final List<LedgerEntry> entries;
  const SessionBonus(this.entries);
  int get total => entries.fold(0, (s, e) => s + e.delta);
}

/// Study rules applied to stored data. No Flutter here, so it is tested
/// with an in-memory database.
class StudyService {
  final UserDb db;
  final Catalog catalog;
  final AppSettings settings;
  final Clock clock;
  final EngineConfig config;

  /// 'vocab' or 'grammar': which items, schedule settings and daily bonus.
  final String deck;

  /// Only this level ('kana', 'n5' …); null for the whole path.
  final String? level;

  late final SrsScheduler scheduler = SrsScheduler(
    deck == grammarDeck ? config.grammar : config.vocab,
  );
  late final Grader grader = Grader(config.grader);
  late final RewardEngine rewards = RewardEngine(
    config: config.rewards,
    newId: UserDb.newId,
  );
  late final StudyRepo repo = StudyRepo(db);
  late final LedgerRepo ledger = LedgerRepo(db);
  late final ResponseTimeTracker times = repo.responseTimes();

  StudyService({
    required this.db,
    required this.catalog,
    required this.settings,
    this.clock = const Clock(),
    this.deck = vocabDeck,
    this.level,
    EngineConfig? config,
  }) : config =
           config ??
           EngineConfig(
             vocab: SrsConfig(desiredRetention: settings.vocabRetention),
             grammar: SrsConfig(desiredRetention: settings.grammarRetention),
           );

  /// Words and kana are reviewed as self-rated flashcards.
  bool get flashcards => deck == vocabDeck && settings.flashcards;

  int get _newPerDay =>
      deck == grammarDeck ? settings.grammarNewPerDay : settings.vocabNewPerDay;

  int studyDay([DateTime? utc]) => studyDayNumber(
    utc ?? clock.nowUtc(),
    tzOffsetMinutes: clock.tzOffsetMinutes(),
    dayStartHour: settings.dayStartHour,
  );

  QueueSettings get _queueSettings =>
      QueueSettings(newPerDay: _newPerDay, dayStartHour: settings.dayStartHour);

  /// Cards that exist in the database plus the virtual new cards on the
  /// learning path. A word's recall card becomes available only after its
  /// recognition card was introduced.
  List<QueueCard> _queueCards(Map<String, StoredCard> stored) {
    final out = <QueueCard>[];
    // Items never started are taken strictly in path order and can never be
    // buried (nothing of theirs was seen), so the first newPerDay of them
    // are all the queue can use; the rest of the path is skipped.
    var freshLeft = _newPerDay;
    for (final item in catalog.itemsOf(deck)) {
      if (level != null && item.level != level) continue;
      final ids = item.cardIds;
      // Choosing the kana level studies kana even with the setting off.
      if (item is KanaStudy && !settings.includeKana && level != 'kana') {
        // Kana already started keep their schedule.
        final s = stored[ids.first];
        if (s != null && !s.state.isNew) out.add(_fromStored(s, item, 0));
        continue;
      }
      if (!ids.any(stored.containsKey)) {
        if (freshLeft <= 0) continue;
        freshLeft--;
      }
      for (var f = 0; f < ids.length; f++) {
        final facet = item.facets[f];
        // Flashcards are one card per word, like Kaishi: reverse (typing)
        // cards are left out, even ones started in quiz mode.
        if (flashcards && facet == Facet.recall) continue;
        final id = ids[f];
        final s = stored[id];
        final order = item.pathOrder * 4 + f;
        if (s != null) {
          out.add(_fromStored(s, item, order));
        } else if (facet == Facet.recall &&
            !stored.containsKey(cardIdFor(item.id, Facet.recog))) {
          continue;
        } else {
          out.add(
            QueueCard(
              cardId: id,
              itemId: item.id,
              state: CardState.initial,
              newOrder: order,
            ),
          );
        }
      }
    }
    return out;
  }

  QueueCard _fromStored(StoredCard s, StudyItem item, int order) => QueueCard(
    cardId: s.id,
    itemId: s.itemId,
    state: s.state,
    newOrder: order,
    suspended: s.suspended,
  );

  TodayPlan plan() {
    final now = clock.nowUtc();
    final day = studyDay(now);
    // New cards per day count per level when one level is studied, so
    // finishing N5's new words does not use up N4's.
    final introduced = level == null
        ? repo.introducedOn(day, deck)
        : repo
              .introducedItemsOn(day, deck)
              .where((id) => catalog.byId[id]?.level == level)
              .length;
    final q = QueueBuilder(scheduler, _queueSettings).build(
      cards: _queueCards(repo.cards(deck: deck)),
      nowUtc: now,
      tzOffsetMinutes: clock.tzOffsetMinutes(),
      newIntroducedToday: introduced,
      itemsSeenToday: repo.itemsReviewedOn(day, deck),
    );
    final perReview =
        (times.median(deck == grammarDeck ? 'cloze.choice' : 'recog.choice') ??
            6000) +
        3000;
    final ms = q.dueCount * perReview + q.newCards.length * (perReview * 3);
    return TodayPlan(
      q,
      day,
      (_newPerDay - introduced).clamp(0, 999),
      (ms / 60000).ceil(),
    );
  }

  /// Order for a session: steps, then reviews with new cards spread among
  /// them so a session does not end with a block of unfamiliar items.
  List<String> sessionOrder(TodayPlan p) {
    final q = p.queue;
    final out = [for (final c in q.steps) c.cardId];
    final reviews = [for (final c in q.reviews) c.cardId];
    final fresh = [for (final c in q.newCards) c.cardId];
    if (fresh.isEmpty) return out..addAll(reviews);
    final every = (reviews.length / (fresh.length + 1)).floor().clamp(1, 1000);
    var r = 0;
    for (final n in fresh) {
      for (var i = 0; i < every && r < reviews.length; i++) {
        out.add(reviews[r++]);
      }
      out.add(n);
    }
    out.addAll(reviews.skip(r));
    return out;
  }

  StoredCard? stored(String cardId) => repo.card(cardId);

  Question question(String cardId) {
    final item = catalog.byId[itemIdOf(cardId)]!;
    final facet = facetOf(cardId)!;
    final s = stored(cardId);
    final reps = s?.state.reps ?? 0;
    // Recall of an already introduced word needs no introduction.
    final needsIntro = s == null && facet != Facet.recall;
    if (flashcards && item is! GrammarStudy) {
      // The back of the card is the introduction.
      return Question(
        cardId: cardId,
        item: item,
        facet: facet,
        type: '${facet.name}.flash',
      );
    }
    switch (facet) {
      case Facet.recog || Facet.listen:
        final w = (item as WordStudy);
        return Question(
          cardId: cardId,
          item: item,
          facet: facet,
          type: '${facet.name}.choice',
          needsIntro: needsIntro,
          choices: buildChoices(
            correctItemId: w.id,
            correct: w.word.shortMeaning,
            group: w.group,
            pool: catalog.meaningPool,
            seedKey: '$cardId#$reps',
          ),
        );
      case Facet.recall:
        return Question(
          cardId: cardId,
          item: item,
          facet: facet,
          type: 'recall.type',
        );
      case Facet.kana:
        return Question(
          cardId: cardId,
          item: item,
          facet: facet,
          type: 'kana.type',
          needsIntro: needsIntro,
        );
      case Facet.cloze:
        return clozeQuestion(
          item as GrammarStudy,
          seedKey: '$cardId#$reps',
          // The lesson shows the first examples; questions start after them.
          pick: reps + 3,
          needsIntro: needsIntro,
        );
    }
  }

  /// A fill-the-blank question on one of the point's translated examples
  /// (a different one each review, so the rule is learned, not the sentence).
  static Question clozeQuestion(
    GrammarStudy g, {
    required String seedKey,
    required int pick,
    bool needsIntro = false,
  }) {
    final examples = g.point.clozeExamples;
    final ex = examples[pick % examples.length];
    return Question(
      cardId: cardIdFor(g.id, Facet.cloze),
      item: g,
      facet: Facet.cloze,
      type: 'cloze.choice',
      needsIntro: needsIntro,
      example: ex,
      choices: buildChoices(
        correctItemId: '=',
        correct: ex.answer,
        group: '',
        pool: [
          for (final (i, w) in ex.wrong.indexed)
            DistractorCandidate('$i', w, ''),
        ],
        seedKey: seedKey,
      ),
    );
  }

  /// Checks a typed answer. A different word with the same meaning is
  /// reported as [AnswerCheck.synonym] so the learner can try again instead
  /// of being marked wrong for a valid answer.
  AnswerCheck checkTyped(Question q, String input) {
    final item = q.item;
    if (item is KanaStudy) {
      final k = item.kana;
      final ok =
          readingMatches(input, [k.char]) ||
          input.trim().toLowerCase() == k.romaji;
      return ok ? AnswerCheck.correct : AnswerCheck.wrong;
    }
    final w = (item as WordStudy).word;
    if (readingMatches(input, w.acceptedReadings)) return AnswerCheck.correct;
    for (final other in catalog.wordsWithMeaning(w.shortMeaning)) {
      if (other.id != w.id &&
          readingMatches(input, other.word.acceptedReadings)) {
        return AnswerCheck.synonym;
      }
    }
    return AnswerCheck.wrong;
  }

  /// Marks a new card as introduced (counts toward today's new cards).
  void introduce(Question q) {
    final now = clock.nowUtc();
    repo.introduce(
      cardId: q.cardId,
      itemId: q.item.id,
      deck: deck,
      facet: q.facet,
      nowUtc: now,
      studyDay: studyDay(now),
    );
  }

  /// When each rating would bring [q] back (Anki shows these on its
  /// buttons). Nothing is saved.
  Map<Rating, Duration> intervals(Question q) {
    final now = clock.nowUtc();
    final before = stored(q.cardId)?.state ?? CardState.initial;
    final at = before.lastReview != null && now.isBefore(before.lastReview!)
        ? before.lastReview!
        : now;
    return {
      for (final r in Rating.values)
        r: scheduler
            .review(cardId: q.cardId, state: before, rating: r, nowUtc: at)
            .after
            .due!
            .difference(at),
    };
  }

  /// Records an answer. [selfRating] (flashcards) replaces the grader.
  AnswerResult answer(
    Question q,
    AnswerEvent e, {
    String? sessionId,
    String? answerRaw,
    Rating? selfRating,
  }) {
    final now = clock.nowUtc();
    final day = studyDay(now);
    final s = stored(q.cardId);
    final before = s?.state ?? CardState.initial;
    final rating =
        selfRating ?? grader.grade(e, medianMs: times.median(q.type));
    // Answer times can't go backwards if the clock was changed.
    final at = before.lastReview != null && now.isBefore(before.lastReview!)
        ? before.lastReview!
        : now;
    final outcome = scheduler.review(
      cardId: q.cardId,
      state: before,
      rating: rating,
      nowUtc: at,
    );
    final firstMastered =
        s?.firstMasteredAt == null && config.mastery.isMastered(outcome.after);
    final leech = scheduler.isLeech(outcome.after);
    final logId = UserDb.newId();
    final coins = rewards.forReview(
      ReviewRewardInput(
        reviewLogId: logId,
        cardId: q.cardId,
        deck: deck,
        statusBefore: before.status,
        rating: rating,
        responseMs: e.responseMs,
        graduated: outcome.graduated,
        firstMastered: firstMastered,
      ),
      nowUtc: now,
      studyDay: day,
      today: ledger.totalsFor(day),
    );
    final paid = coins.where((c) => !ledger.has(c.idempotencyKey)).toList();
    repo.recordReview(
      ReviewRecordInput(
        logId: logId,
        cardId: q.cardId,
        itemId: q.item.id,
        deck: deck,
        facet: q.facet,
        sessionId: sessionId,
        tsUtc: at,
        tzOffsetMin: clock.tzOffsetMinutes(),
        studyDay: day,
        questionType: q.type,
        answerRaw: answerRaw,
        answer: e,
        outcome: outcome,
        rating: rating,
        paramsVersion: config.vocab.paramsVersion,
        isLeech: leech,
        firstMastered: firstMastered,
      ),
      paid,
    );
    times.add(q.type, e, maxResponseMs: config.grader.maxResponseMs);
    return AnswerResult(
      rating,
      outcome,
      paid,
      graduated: outcome.graduated,
      mastered: firstMastered,
      leech: leech,
    );
  }

  /// Daily-clear and coverage bonuses, paid once each (idempotent).
  SessionBonus finishSession({required bool answeredAny}) {
    final now = clock.nowUtc();
    final day = studyDay(now);
    final entries = <LedgerEntry>[];
    if (answeredAny && plan().dueCount == 0) {
      entries.add(rewards.dailyClear(deck: deck, nowUtc: now, studyDay: day));
    }
    final cov = coverage(now);
    cov.forEach((level, c) {
      entries.addAll(
        rewards.forCoverage(
          deck: deck,
          level: level,
          coverage: c,
          nowUtc: now,
          studyDay: day,
        ),
      );
    });
    final added = db.tx(() => ledger.insertAll(entries));
    return SessionBonus(added);
  }

  List<TrackedCard> trackedCards() {
    final out = <TrackedCard>[];
    for (final c in repo.cards(deck: deck).values) {
      if (c.state.isNew || c.suspended) continue;
      final item = catalog.byId[c.itemId];
      if (item == null) continue;
      out.add(TrackedCard(c.id, c.itemId, item.level, c.state));
    }
    return out;
  }

  /// Share of each level's items expected to be recalled now (Σ R / total).
  Map<String, double> coverage([DateTime? nowUtc]) {
    final now = nowUtc ?? clock.nowUtc();
    final metrics = Metrics(scheduler, config.mastery);
    final byLevel = <String, List<TrackedCard>>{};
    for (final c in trackedCards()) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    return {
      for (final e in catalog.itemsPerLevel(deck).entries)
        e.key: metrics.coverage(
          cards: byLevel[e.key] ?? const [],
          totalItemsInLevel: e.value,
          nowUtc: now,
        ),
    };
  }
}
