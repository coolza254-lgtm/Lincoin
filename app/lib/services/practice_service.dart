import 'dart:math' as math;

import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/study_repo.dart';
import '../data/user_db.dart';
import 'study_service.dart';

/// An item that has been studied, with what practice needs to know.
class PracticeItem {
  final StudyItem item;

  /// Recall probability now (weakest facet).
  final double r;
  final bool weak;
  final bool recent;
  const PracticeItem(
    this.item,
    this.r, {
    this.weak = false,
    this.recent = false,
  });
}

class DrillAnswer {
  final bool correct;
  final List<LedgerEntry> coins;
  const DrillAnswer(this.correct, this.coins);
  int get coinTotal => coins.fold(0, (a, e) => a + e.delta);
}

/// Practice and challenge questions. Answers go to practice_log only and
/// never change the FSRS schedule (docs/05-modes.md).
class PracticeService {
  final StudyService study;
  PracticeService(this.study);

  UserDb get _db => study.db;
  Catalog get _catalog => study.catalog;

  /// Items with at least one studied card. Weak = likely forgotten, a
  /// leech, or often wrong in practice lately.
  List<PracticeItem> pool() {
    final now = study.clock.nowUtc();
    final today = study.studyDay(now);
    final errors = _recentPracticeErrorRate(today - 14);
    final byItem = <String, List<StoredCard>>{};
    for (final c in study.repo.cards(deck: vocabDeck).values) {
      if (c.suspended || c.state.isNew) continue;
      byItem.putIfAbsent(c.itemId, () => []).add(c);
    }
    final out = <PracticeItem>[];
    byItem.forEach((itemId, cards) {
      final item = _catalog.byId[itemId];
      if (item == null) return;
      var r = 1.0;
      var leech = false;
      var introduced = 1 << 30;
      for (final c in cards) {
        r = math.min(r, study.scheduler.retrievability(c.state, now));
        leech |= c.isLeech;
        introduced = math.min(introduced, c.introducedDay);
      }
      final err = errors[itemId] ?? 0;
      out.add(
        PracticeItem(
          item,
          r,
          weak: r < 0.8 || leech || err >= 0.4,
          recent: today - introduced <= 7,
        ),
      );
    });
    return out;
  }

  Map<String, double> _recentPracticeErrorRate(int fromDay) {
    final n = <String, int>{};
    final wrong = <String, int>{};
    for (final r in _db.db.select(
      'SELECT card_id, is_correct FROM practice_log WHERE study_day >= ?',
      [fromDay],
    )) {
      final item = itemIdOf(r['card_id'] as String);
      n[item] = (n[item] ?? 0) + 1;
      if ((r['is_correct'] as int) == 0) wrong[item] = (wrong[item] ?? 0) + 1;
    }
    return {
      for (final e in n.entries)
        if (e.value >= 3) e.key: (wrong[e.key] ?? 0) / e.value,
    };
  }

  /// [count] distinct items: weak ×3, recent ×2, others ×1 weight.
  List<PracticeItem> pick(
    List<PracticeItem> pool,
    int count,
    math.Random rnd, {
    bool weakOnly = false,
  }) {
    var candidates = weakOnly ? pool.where((p) => p.weak).toList() : [...pool];
    if (weakOnly && candidates.length < count) {
      // Not enough weak items: add the least well known ones.
      final rest = pool.where((p) => !p.weak).toList()
        ..sort((a, b) => a.r.compareTo(b.r));
      candidates = [...candidates, ...rest.take(count - candidates.length)];
    }
    final out = <PracticeItem>[];
    while (out.length < count && candidates.isNotEmpty) {
      final weights = [
        for (final p in candidates) p.weak ? 3.0 : (p.recent ? 2.0 : 1.0),
      ];
      var x = rnd.nextDouble() * weights.fold(0.0, (a, b) => a + b);
      var i = 0;
      while (i < weights.length - 1 && x >= weights[i]) {
        x -= weights[i];
        i++;
      }
      out.add(candidates.removeAt(i));
    }
    return out;
  }

  /// A question about [p]. [choiceOnly] is used where typing would be unfair
  /// (timed challenges).
  Question question(
    PracticeItem p,
    math.Random rnd, {
    bool choiceOnly = false,
  }) {
    final seed = '${p.item.id}#${rnd.nextInt(1 << 30)}';
    final item = p.item;
    if (item is KanaStudy) {
      final typed = !choiceOnly && rnd.nextBool();
      return Question(
        cardId: cardIdFor(item.id, Facet.kana),
        item: item,
        facet: Facet.kana,
        type: typed ? 'kana.type' : 'kana.choice',
        choices: typed
            ? null
            : buildChoices(
                correctItemId: item.id,
                correct: item.kana.romaji,
                group: item.kana.script,
                pool: _catalog.romajiPool,
                seedKey: seed,
              ),
      );
    }
    final w = item as WordStudy;
    final forms = choiceOnly
        ? const [QuestionForm.meaningChoice, QuestionForm.wordChoice]
        : const [
            QuestionForm.meaningChoice,
            QuestionForm.wordChoice,
            QuestionForm.readingType,
          ];
    final form = forms[rnd.nextInt(forms.length)];
    return switch (form) {
      QuestionForm.readingType => Question(
        cardId: cardIdFor(w.id, Facet.recall),
        item: w,
        facet: Facet.recall,
        type: 'recall.type',
      ),
      QuestionForm.wordChoice => Question(
        cardId: cardIdFor(w.id, Facet.recall),
        item: w,
        facet: Facet.recall,
        type: 'reverse.choice',
        choices: buildChoices(
          correctItemId: w.id,
          correct: w.word.headword,
          group: w.group,
          pool: _catalog.headwordPool,
          seedKey: seed,
        ),
      ),
      _ => Question(
        cardId: cardIdFor(w.id, Facet.recog),
        item: w,
        facet: Facet.recog,
        type: 'recog.choice',
        choices: buildChoices(
          correctItemId: w.id,
          correct: w.word.shortMeaning,
          group: w.group,
          pool: _catalog.meaningPool,
          seedKey: seed,
        ),
      ),
    };
  }

  AnswerCheck checkTyped(Question q, String input) =>
      study.checkTyped(q, input);

  /// Logs an answer. In practice mode it may pay Lincoin (diminishing
  /// returns per day, see RewardConfig); challenge answers never pay.
  DrillAnswer record({
    required Question q,
    required bool correct,
    required int responseMs,
    required String mode,
    required String sessionId,
    bool weak = false,
    int combo = 0,
  }) {
    final now = study.clock.nowUtc();
    final day = study.studyDay(now);
    final id = UserDb.newId();
    final ledger = LedgerRepo(_db);
    return _db.tx(() {
      _db.db.execute(
        'INSERT INTO practice_log(id, card_id, session_id, mode, ts_utc, '
        'study_day, question_type, is_correct, response_ms) '
        'VALUES (?,?,?,?,?,?,?,?,?)',
        [
          id,
          q.cardId,
          sessionId,
          mode,
          now.millisecondsSinceEpoch,
          day,
          q.type,
          correct ? 1 : 0,
          responseMs,
        ],
      );
      if (mode != 'practice') return DrillAnswer(correct, const []);
      final e = study.rewards.forPractice(
        PracticeRewardInput(
          practiceLogId: id,
          cardId: q.cardId,
          isCorrect: correct,
          responseMs: responseMs,
          isWeakItem: weak,
          comboCount: combo,
        ),
        nowUtc: now,
        studyDay: day,
        today: ledger.totalsFor(day),
      );
      if (e == null || e.delta <= 0) {
        // Record the raw points even when rounding paid 0, so the daily
        // diminishing-returns tiers still advance.
        if (e != null) ledger.insertAll([e]);
        return DrillAnswer(correct, const []);
      }
      return DrillAnswer(correct, ledger.insertAll([e]));
    });
  }

  /// Practice Lincoin earned today and the current payout rate.
  (int coins, double rate) todayPractice() {
    final day = study.studyDay();
    final totals = LedgerRepo(_db).totalsFor(day);
    final coins = LedgerRepo(_db)
        .entries(fromDay: day)
        .where((e) => e.studyDay == day && e.reason == LedgerReason.practice)
        .fold(0, (a, e) => a + e.delta);
    final tiers = study.config.rewards.practiceTiers;
    var rate = tiers.last.$2;
    for (final (upTo, r) in tiers) {
      if (totals.practiceRaw < upTo) {
        rate = r;
        break;
      }
    }
    return (coins, rate);
  }
}
