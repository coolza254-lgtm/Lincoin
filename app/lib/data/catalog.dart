import 'package:lincoin_core/lincoin_core.dart';

import 'content_db.dart';

/// Levels in teaching order. Only levels with content appear in the app.
const vocabLevels = ['kana', 'n5', 'n4', 'n3', 'n2', 'n1'];

/// Something that can be studied: a kana character or a word.
sealed class StudyItem {
  String get id;

  /// 'kana', 'n5', …
  String get level;

  /// Position on the learning path (kana first, then N5 …).
  int get pathOrder;
  List<Facet> get facets;
}

class KanaStudy extends StudyItem {
  final KanaItem kana;
  @override
  final int pathOrder;
  KanaStudy(this.kana, this.pathOrder);

  @override
  String get id => kana.id;
  @override
  String get level => 'kana';
  @override
  List<Facet> get facets => const [Facet.kana];
}

class WordStudy extends StudyItem {
  final WordItem word;
  @override
  final int pathOrder;
  WordStudy(this.word, this.pathOrder);

  @override
  String get id => word.id;
  @override
  String get level => 'n${word.level}';
  @override
  List<Facet> get facets => const [Facet.recog, Facet.recall];

  String get group => word.pos.isEmpty ? '' : word.pos.first;
}

/// Content loaded into memory for fast queue building and question making.
class Catalog {
  final ContentInfo info;
  final List<StudyItem> path;
  final Map<String, StudyItem> byId;
  final List<SourceCredit> sources;
  final ContentDb db;

  Catalog._(this.info, this.path, this.byId, this.sources, this.db);

  factory Catalog.load(ContentDb db) {
    final path = <StudyItem>[];
    var order = 0;
    for (final k in db.kana()) {
      path.add(KanaStudy(k, order++));
    }
    for (final w in db.words()) {
      path.add(WordStudy(w, order++));
    }
    return Catalog._(
      db.info(),
      path,
      {for (final i in path) i.id: i},
      db.sources(),
      db,
    );
  }

  Map<String, int> get itemsPerLevel {
    final m = <String, int>{};
    for (final i in path) {
      m[i.level] = (m[i.level] ?? 0) + 1;
    }
    return m;
  }

  late final List<DistractorCandidate> meaningPool = [
    for (final i in path)
      if (i is WordStudy)
        DistractorCandidate(i.id, i.word.shortMeaning, i.group),
  ];

  /// Words sharing [meaning] (for tolerating a synonym typed in recall).
  List<WordStudy> wordsWithMeaning(String meaning) => [
    for (final i in path)
      if (i is WordStudy && i.word.shortMeaning == meaning) i,
  ];
}
