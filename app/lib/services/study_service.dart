import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/settings_repo.dart';
import '../data/study_repo.dart';
import '../data/user_db.dart';

const vocabDeck = 'vocab';

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

  const Question({
    required this.cardId,
    required this.item,
    required this.facet,
    required this.type,
    this.choices,
    this.needsIntro = false,
  });

  bool get isTyped => choices == null;
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

  late final SrsScheduler scheduler = SrsScheduler(config.vocab);
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
    EngineConfig? config,
  }) : config =
           config ??
           EngineConfig(
             vocab: SrsConfig(desiredRetention: settings.vocabRetention),
           );

  int studyDay([DateTime? utc]) => studyDayNumber(
    utc ?? clock.nowUtc(),
    tzOffsetMinutes: clock.tzOffsetMinutes(),
    dayStartHour: settings.dayStartHour,
  );

  QueueSettings get _queueSettings => QueueSettings(
    newPerDay: settings.vocabNewPerDay,
    dayStartHour: settings.dayStartHour,
  );

  /// Cards that exist in the database plus the virtual new cards on the
  /// learning path. A word's recall card becomes available only after its
  /// recognition card was introduced.
  List<QueueCard> _queueCards(Map<String, StoredCard> stored) {
    final out = <QueueCard>[];
    for (final item in catalog.path) {
      if (item is KanaStudy && !settings.includeKana) {
        // Kana already started keep their schedule.
        final id = cardIdFor(item.id, Facet.kana);
        final s = stored[id];
        if (s != null && !s.state.isNew) out.add(_fromStored(s, item, 0));
        continue;
      }
      for (var f = 0; f < item.facets.length; f++) {
        final facet = item.facets[f];
        final id = cardIdFor(item.id, facet);
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
    final introduced = repo.introducedOn(day, vocabDeck);
    final q = QueueBuilder(scheduler, _queueSettings).build(
      cards: _queueCards(repo.cards(deck: vocabDeck)),
      nowUtc: now,
      tzOffsetMinutes: clock.tzOffsetMinutes(),
      newIntroducedToday: introduced,
      itemsSeenToday: repo.itemsReviewedOn(day, vocabDeck),
    );
    final perReview = (times.median('recog.choice') ?? 6000) + 3000;
    final ms = q.dueCount * perReview + q.newCards.length * (perReview * 3);
    return TodayPlan(
      q,
      day,
      (settings.vocabNewPerDay - introduced).clamp(0, 999),
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
    }
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
      deck: vocabDeck,
      facet: q.facet,
      nowUtc: now,
      studyDay: studyDay(now),
    );
  }

  AnswerResult answer(
    Question q,
    AnswerEvent e, {
    String? sessionId,
    String? answerRaw,
  }) {
    final now = clock.nowUtc();
    final day = studyDay(now);
    final s = stored(q.cardId);
    final before = s?.state ?? CardState.initial;
    final rating = grader.grade(e, medianMs: times.median(q.type));
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
        deck: vocabDeck,
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
        deck: vocabDeck,
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
      entries.add(
        rewards.dailyClear(deck: vocabDeck, nowUtc: now, studyDay: day),
      );
    }
    final cov = coverage(now);
    cov.forEach((level, c) {
      entries.addAll(
        rewards.forCoverage(
          deck: vocabDeck,
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
    for (final c in repo.cards(deck: vocabDeck).values) {
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
      for (final e in catalog.itemsPerLevel.entries)
        e.key: metrics.coverage(
          cards: byLevel[e.key] ?? const [],
          totalItemsInLevel: e.value,
          nowUtc: now,
        ),
    };
  }
}
