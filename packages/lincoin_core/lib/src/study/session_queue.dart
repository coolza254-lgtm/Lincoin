/// Order of cards inside one study session.
///
/// Cards still in learning steps come back when their step is due (or at
/// once if nothing else is waiting), and a newly introduced card is asked
/// for the first time only after a few other cards, so the first graded
/// answer is not read straight off the introduction screen.
class SessionQueue {
  /// Other cards shown between a new card's introduction and its question.
  final int introGap;

  /// Steps due within this window are shown now rather than waited for.
  final Duration learnAhead;

  final List<_Entry> _waiting = [];
  final List<String> _fresh = [];
  int _counter = 0;

  SessionQueue({
    Iterable<String> initial = const [],
    this.introGap = 3,
    this.learnAhead = const Duration(minutes: 20),
  }) {
    _fresh.addAll(initial);
  }

  bool get isEmpty => _fresh.isEmpty && _waiting.isEmpty;
  int get length => _fresh.length + _waiting.length;

  /// Next card at [nowUtc], or null when the session is done (steps due
  /// later than [learnAhead] stay for another session).
  String? next(DateTime nowUtc) {
    _waiting.sort((a, b) {
      final c = a.dueUtc.compareTo(b.dueUtc);
      return c != 0 ? c : a.seq.compareTo(b.seq);
    });
    _counter++;
    // A step that is already due (or a delayed first question whose gap has
    // passed) goes before fresh cards.
    for (var i = 0; i < _waiting.length; i++) {
      final w = _waiting[i];
      if (w.dueUtc.isAfter(nowUtc)) break;
      if (w.afterCount == null || _counter > w.afterCount!) {
        _waiting.removeAt(i);
        return w.cardId;
      }
    }
    if (_fresh.isNotEmpty) return _fresh.removeAt(0);
    // Nothing fresh left: show the earliest waiting card within learnAhead.
    if (_waiting.isNotEmpty &&
        !_waiting.first.dueUtc.isAfter(nowUtc.add(learnAhead))) {
      return _waiting.removeAt(0).cardId;
    }
    return null;
  }

  /// Puts a card back until [dueUtc] (learning / relearning step).
  void requeue(String cardId, DateTime dueUtc) =>
      _waiting.add(_Entry(cardId, dueUtc, null, _counter));

  /// Asks a just-introduced card after [introGap] other cards.
  void afterIntro(String cardId, DateTime nowUtc) =>
      _waiting.add(_Entry(cardId, nowUtc, _counter + introGap, _counter));

  /// Number of waiting step cards that are due later than [nowUtc]+learnAhead.
  int laterSteps(DateTime nowUtc) =>
      _waiting.where((w) => w.dueUtc.isAfter(nowUtc.add(learnAhead))).length;
}

class _Entry {
  final String cardId;
  final DateTime dueUtc;
  final int? afterCount;
  final int seq;
  _Entry(this.cardId, this.dueUtc, this.afterCount, this.seq);
}
