import '../time/study_day.dart';
import 'card_state.dart';
import 'scheduler.dart';

/// Minimal view of a card needed to build today's queue.
class QueueCard {
  final String cardId;

  /// Word or grammar point the card belongs to; facets share an item.
  final String itemId;
  final CardState state;

  /// Position in the teaching order; only used for new cards.
  final int newOrder;
  final bool suspended;

  const QueueCard({
    required this.cardId,
    required this.itemId,
    required this.state,
    this.newOrder = 0,
    this.suspended = false,
  });
}

class QueueSettings {
  final int newPerDay;

  /// Stop introducing new cards while more than this many reviews are due.
  final int backlogThreshold;

  /// Learning cards due within this window are shown now instead of waiting.
  final Duration learnAhead;
  final int dayStartHour;

  const QueueSettings({
    this.newPerDay = 10,
    this.backlogThreshold = 150,
    this.learnAhead = const Duration(minutes: 20),
    this.dayStartHour = 4,
  });
}

class StudyQueue {
  /// Cards in learning/relearning steps, earliest due first.
  final List<QueueCard> steps;

  /// Review cards due today, lowest recall probability first.
  final List<QueueCard> reviews;
  final List<QueueCard> newCards;

  /// Held back until tomorrow because a sibling facet is shown today.
  final List<QueueCard> buriedSiblings;

  /// New cards were withheld because of the review backlog.
  final bool newCardsPausedForBacklog;

  const StudyQueue({
    required this.steps,
    required this.reviews,
    required this.newCards,
    required this.buriedSiblings,
    required this.newCardsPausedForBacklog,
  });

  int get dueCount => steps.length + reviews.length;
}

/// Builds today's queue: learning steps, then due reviews ordered by
/// retrievability, then new cards within the daily limit. At most one facet
/// per item is scheduled per study day (steps of a card already started today
/// are exempt), so one facet never gives away another's answer.
class QueueBuilder {
  final SrsScheduler scheduler;
  final QueueSettings settings;

  const QueueBuilder(this.scheduler, this.settings);

  StudyQueue build({
    required Iterable<QueueCard> cards,
    required DateTime nowUtc,
    required int tzOffsetMinutes,

    /// New cards already introduced today (counts against [newPerDay]).
    int newIntroducedToday = 0,

    /// Items with any card answered earlier today.
    Set<String> itemsSeenToday = const {},
  }) {
    final today = _day(nowUtc, tzOffsetMinutes);
    final stepCards = <QueueCard>[];
    final dueReviews = <QueueCard>[];
    final newCards = <QueueCard>[];

    for (final c in cards) {
      if (c.suspended) continue;
      final s = c.state;
      if (s.isNew) {
        newCards.add(c);
      } else if (s.inSteps) {
        if (!s.due!.isAfter(nowUtc.add(settings.learnAhead))) stepCards.add(c);
      } else if (_day(s.due!, tzOffsetMinutes) <= today) {
        dueReviews.add(c);
      }
    }

    stepCards.sort((a, b) => a.state.due!.compareTo(b.state.due!));
    final r = {
      for (final c in dueReviews)
        c.cardId: scheduler.retrievability(c.state, nowUtc)
    };
    dueReviews.sort((a, b) {
      final byR = r[a.cardId]!.compareTo(r[b.cardId]!);
      return byR != 0 ? byR : a.cardId.compareTo(b.cardId);
    });
    newCards.sort((a, b) {
      final byOrder = a.newOrder.compareTo(b.newOrder);
      return byOrder != 0 ? byOrder : a.cardId.compareTo(b.cardId);
    });

    final claimed = {...itemsSeenToday, for (final c in stepCards) c.itemId};
    final buried = <QueueCard>[];
    List<QueueCard> takeUnclaimed(List<QueueCard> source, [int? limit]) {
      final out = <QueueCard>[];
      for (final c in source) {
        if (limit != null && out.length >= limit) break;
        if (claimed.contains(c.itemId)) {
          buried.add(c);
          continue;
        }
        claimed.add(c.itemId);
        out.add(c);
      }
      return out;
    }

    final reviews = takeUnclaimed(dueReviews);
    final paused =
        stepCards.length + reviews.length > settings.backlogThreshold;
    final remainingNew = paused
        ? 0
        : (settings.newPerDay - newIntroducedToday)
            .clamp(0, settings.newPerDay);
    final introduced = takeUnclaimed(newCards, remainingNew);

    return StudyQueue(
      steps: stepCards,
      reviews: reviews,
      newCards: introduced,
      buriedSiblings: buried,
      newCardsPausedForBacklog: paused,
    );
  }

  int _day(DateTime utc, int tz) => studyDayNumber(utc,
      tzOffsetMinutes: tz, dayStartHour: settings.dayStartHour);
}
