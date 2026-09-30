import '../util/hash.dart';

/// Question facets. The name is part of the card id (`<item>#<facet>`) and
/// is stored in the database, so names must never change.
enum Facet {
  /// See the Japanese word → pick its Thai meaning.
  recog,

  /// See the Thai meaning → type the reading.
  recall,

  /// Hear the word → pick its meaning (off by default).
  listen,

  /// See a kana character → type its romaji.
  kana,

  /// Grammar: fill the blank in an example sentence (Thai translation shown).
  cloze;

  static Facet? tryParse(String name) =>
      values.where((f) => f.name == name).firstOrNull;
}

String cardIdFor(String itemId, Facet facet) => '$itemId#${facet.name}';

/// Item id part of a card id.
String itemIdOf(String cardId) {
  final i = cardId.lastIndexOf('#');
  return i < 0 ? cardId : cardId.substring(0, i);
}

Facet? facetOf(String cardId) {
  final i = cardId.lastIndexOf('#');
  return i < 0 ? null : Facet.tryParse(cardId.substring(i + 1));
}

/// A possible wrong answer for a multiple-choice question.
class DistractorCandidate {
  final String itemId;
  final String text;

  /// Candidates in the same group (e.g. part of speech) are preferred, so
  /// the right answer cannot be spotted from its word class alone.
  final String group;

  const DistractorCandidate(this.itemId, this.text, this.group);
}

class ChoiceSet {
  final List<String> options;
  final int correctIndex;
  const ChoiceSet(this.options, this.correctIndex);
}

/// Builds multiple-choice options. Deterministic for a given [seedKey]
/// (card id + repetition count), so a question looks the same when rebuilt
/// and tests are reproducible, but changes from one review to the next.
ChoiceSet buildChoices({
  required String correctItemId,
  required String correct,
  required String group,
  required Iterable<DistractorCandidate> pool,
  required String seedKey,
  int optionCount = 4,
}) {
  // Each candidate is hashed once (the pool can hold thousands of words and
  // this runs for every question), then ordered by that rank.
  final same = <(int, DistractorCandidate)>[];
  final other = <(int, DistractorCandidate)>[];
  for (final c in pool) {
    if (c.itemId == correctItemId || c.text.isEmpty) continue;
    final r = (fnv1a32('$seedKey|${c.itemId}'), c);
    (c.group == group ? same : other).add(r);
  }
  int byRank((int, DistractorCandidate) a, (int, DistractorCandidate) b) =>
      a.$1.compareTo(b.$1);
  final seen = {correct};
  final picked = <String>[];
  void take(List<(int, DistractorCandidate)> list) {
    if (picked.length >= optionCount - 1) return;
    list.sort(byRank);
    for (final (_, c) in list) {
      if (picked.length >= optionCount - 1) break;
      if (seen.add(c.text)) picked.add(c.text);
    }
  }

  take(same);
  take(other);
  final slot = fnv1a32('$seedKey|slot') % (picked.length + 1);
  final options = [...picked]..insert(slot, correct);
  return ChoiceSet(options, slot);
}
