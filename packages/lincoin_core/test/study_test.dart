import 'package:lincoin_core/lincoin_core.dart';
import 'package:test/test.dart';

void main() {
  group('card ids', () {
    test('round trip', () {
      final id = cardIdFor('w:1269320', Facet.recall);
      expect(id, 'w:1269320#recall');
      expect(itemIdOf(id), 'w:1269320');
      expect(facetOf(id), Facet.recall);
      expect(facetOf('k:hira.a#unknown'), isNull);
    });
  });

  group('buildChoices', () {
    final pool = [
      for (var i = 0; i < 20; i++)
        DistractorCandidate('w:$i', 'meaning $i', i.isEven ? 'n' : 'v'),
      const DistractorCandidate('w:dup', 'meaning 2', 'n'),
    ];

    test('has the answer once, distinct options, prefers same group', () {
      final c = buildChoices(
          correctItemId: 'w:0',
          correct: 'meaning 0',
          group: 'n',
          pool: pool,
          seedKey: 'w:0#recog#0');
      expect(c.options, hasLength(4));
      expect(c.options[c.correctIndex], 'meaning 0');
      expect(c.options.toSet(), hasLength(4));
      for (final o in c.options) {
        final n = int.parse(o.split(' ').last);
        expect(n.isEven, isTrue, reason: 'same group first: $o');
      }
    });

    test('deterministic per seed, varies between seeds', () {
      ChoiceSet make(String seed) => buildChoices(
          correctItemId: 'w:0',
          correct: 'meaning 0',
          group: 'n',
          pool: pool,
          seedKey: seed);
      expect(make('a').options, make('a').options);
      final variants = {
        for (var i = 0; i < 20; i++) make('s$i').options.join('|')
      };
      expect(variants.length, greaterThan(5));
      final slots = {for (var i = 0; i < 40; i++) make('s$i').correctIndex};
      expect(slots, {0, 1, 2, 3});
    });

    test('small pool gives fewer options', () {
      final c = buildChoices(
          correctItemId: 'a',
          correct: 'x',
          group: 'n',
          pool: const [DistractorCandidate('b', 'y', 'v')],
          seedKey: 'k');
      expect(c.options.toSet(), {'x', 'y'});
    });
  });

  group('SessionQueue', () {
    final t0 = DateTime.utc(2026, 1, 1, 10);

    test('fresh cards in order, then done', () {
      final q = SessionQueue(initial: ['a', 'b']);
      expect(q.next(t0), 'a');
      expect(q.next(t0), 'b');
      expect(q.next(t0), isNull);
      expect(q.isEmpty, isTrue);
    });

    test('introduced card is asked after the gap', () {
      final q = SessionQueue(initial: ['n', 'a', 'b', 'c', 'd'], introGap: 2);
      expect(q.next(t0), 'n');
      q.afterIntro('n', t0);
      expect(q.next(t0), 'a');
      expect(q.next(t0), 'b');
      expect(q.next(t0), 'n');
      expect(q.next(t0), 'c');
    });

    test('due step goes before fresh cards; future step waits', () {
      final q = SessionQueue(initial: ['a', 'b', 'c']);
      expect(q.next(t0), 'a');
      q.requeue('a', t0.add(const Duration(minutes: 1)));
      expect(q.next(t0), 'b');
      expect(q.next(t0.add(const Duration(minutes: 2))), 'a');
      expect(q.next(t0.add(const Duration(minutes: 2))), 'c');
    });

    test('with nothing fresh, a step within learnAhead is shown early', () {
      final q = SessionQueue(initial: ['a']);
      expect(q.next(t0), 'a');
      q.requeue('a', t0.add(const Duration(minutes: 10)));
      expect(q.next(t0), 'a');
      q.requeue('a', t0.add(const Duration(hours: 2)));
      expect(q.next(t0), isNull);
      expect(q.laterSteps(t0), 1);
    });
  });

  test('long vowel mark matches written-out vowels', () {
    expect(readingMatches('koohii', ['コーヒー']), isTrue);
    expect(readingMatches('ko-hi-', ['コーヒー']), isTrue);
    expect(readingMatches('ビール', ['びいる']), isTrue);
    expect(readingMatches('kohi', ['コーヒー']), isFalse);
  });

  test('SessionQueue.copy rewinds independently', () {
    final now = DateTime.utc(2026, 10, 1);
    final q = SessionQueue(initial: ['a', 'b', 'c']);
    expect(q.next(now), 'a');
    final saved = q.copy();
    expect(q.next(now), 'b');
    q.requeue('b', now);
    expect(saved.length, 2);
    expect(saved.next(now), 'b');
    expect(q.length, 2);
  });
}
