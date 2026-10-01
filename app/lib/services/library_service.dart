import 'package:lincoin_core/lincoin_core.dart';

import '../data/catalog.dart';
import '../data/study_repo.dart';
import 'study_service.dart';

/// Where a word (or kana) stands, for the library and its detail page.
enum WordProgress { notStarted, learning, relearning, review, mastered }

class LibraryEntry {
  final StudyItem item;

  /// The card studied in sessions (recognition, or the kana card).
  final StoredCard? card;
  final WordProgress progress;

  /// Chance of recalling it now; null before the first answer.
  final double? recall;

  /// Waiting to be reviewed now.
  final bool due;

  const LibraryEntry(
    this.item,
    this.card,
    this.progress,
    this.recall, {
    this.due = false,
  });
}

/// Every vocabulary item with its progress, and search over them.
class LibraryService {
  final StudyService svc;
  LibraryService(this.svc);

  List<LibraryEntry> entries() {
    final now = svc.clock.nowUtc();
    final cards = svc.repo.cards(deck: vocabDeck);
    return [
      for (final item in svc.catalog.itemsOf(vocabDeck))
        entryFor(item, cards[item.cardIds.first], now),
    ];
  }

  LibraryEntry? entry(String itemId) {
    final item = svc.catalog.byId[itemId];
    if (item == null) return null;
    return entryFor(item, svc.stored(item.cardIds.first), svc.clock.nowUtc());
  }

  LibraryEntry entryFor(StudyItem item, StoredCard? card, DateTime now) {
    final s = card?.state;
    if (s == null || s.isNew) {
      return LibraryEntry(item, card, WordProgress.notStarted, null);
    }
    final p = switch (s.status) {
      _ when svc.config.mastery.isMastered(s) => WordProgress.mastered,
      CardStatus.learning || CardStatus.newCard => WordProgress.learning,
      CardStatus.relearning => WordProgress.relearning,
      CardStatus.review => WordProgress.review,
    };
    final r = s.lastReview == null
        ? null
        : svc.scheduler.retrievability(s, now);
    return LibraryEntry(item, card, p, r, due: !s.due!.isAfter(now));
  }

  /// Answers to [cardId], newest first.
  List<ReviewRecord> history(String cardId) =>
      svc.repo.reviewRecords(cardId: cardId).reversed.toList();

  /// Matches kanji, kana, romaji ("taberu"), Thai or English meanings.
  static bool matches(StudyItem item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final kana = katakanaToHiragana(q);
    final romaji = RegExp(r'^[a-z\-]+$').hasMatch(q)
        ? romajiToHiragana(q).replaceAll(RegExp('[a-z]+\$'), '')
        : null;
    bool reads(String r) {
      final h = katakanaToHiragana(r);
      return h.contains(kana) ||
          (romaji != null && romaji.isNotEmpty && h.contains(romaji));
    }

    return switch (item) {
      KanaStudy(:final kana) =>
        kana.char == query.trim() || kana.romaji == q || reads(kana.char),
      WordStudy(:final word) =>
        word.forms.any((f) => f.text.contains(query.trim())) ||
            reads(word.reading) ||
            word.senses.any(
              (s) =>
                  (s.th?.toLowerCase().contains(q) ?? false) ||
                  s.en.toLowerCase().contains(q),
            ),
      GrammarStudy() => false,
    };
  }

  /// Exact hits (headword, reading, first meaning) before partial ones.
  static int rank(StudyItem item, String query) {
    final q = query.trim();
    return switch (item) {
      WordStudy(:final word)
          when word.headword == q ||
              word.reading == q ||
              word.shortMeaning == q =>
        0,
      KanaStudy(:final kana) when kana.char == q || kana.romaji == q => 0,
      _ => 1,
    };
  }
}
