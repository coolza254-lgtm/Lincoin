import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Content schema versions this app can read.
const int supportedContentSchema = 1;

class FuriganaPart {
  final String text;

  /// Reading shown above [text]; null for kana.
  final String? rt;
  const FuriganaPart(this.text, [this.rt]);
}

class KanaItem {
  final String id;
  final String script;
  final String char;
  final String romaji;
  final String row;
  final String group;
  final int ord;
  const KanaItem(
    this.id,
    this.script,
    this.char,
    this.romaji,
    this.row,
    this.group,
    this.ord,
  );
}

class Sense {
  final String id;
  final int ord;
  final String? _posJson;
  final String en;
  final String? th;
  final String? noteTh;
  final String status;
  Sense(
    this.id,
    this.ord,
    this._posJson,
    this.en,
    this.th,
    this.noteTh,
    this.status,
  );

  /// Parsed on first use: most senses are never shown in a session.
  late final List<String> pos = ContentDb._list(_posJson);

  /// Thai gloss, or the English original while untranslated.
  String get display => (th?.isNotEmpty ?? false) ? th! : en;
}

class WordForm {
  final String kind;
  final String text;
  final String? _furiganaJson;
  final bool isPrimary;
  final bool acceptAsAnswer;
  final String? _infoJson;
  WordForm(
    this.kind,
    this.text,
    this._furiganaJson,
    this.isPrimary,
    this.acceptAsAnswer,
    this._infoJson,
  );

  // Parsed on first use: only words on screen need their ruby.
  late final List<FuriganaPart>? furigana = ContentDb._furigana(_furiganaJson);
  late final List<String> info = ContentDb._list(_infoJson);
}

class WordItem {
  final String id;
  final int level;
  final int order;
  final List<String> pos;
  final List<String> tags;
  final List<WordForm> forms;
  final List<Sense> senses;
  final List<String> listReadings;

  WordItem({
    required this.id,
    required this.level,
    required this.order,
    required this.pos,
    required this.tags,
    required this.forms,
    required this.senses,
    required this.listReadings,
  });

  // The getters below run for every question and distractor, so each is
  // worked out once per word.

  /// Usually written in kana (JMdict `uk` on the first sense).
  late final bool usuallyKana = tags.contains('uk');

  late final WordForm? primaryKanji =
      forms.where((f) => f.kind == 'kanji' && f.isPrimary).firstOrNull ??
      forms.where((f) => f.kind == 'kanji').firstOrNull;

  /// The reading taught first (from the JLPT list when it names one).
  late final String reading = listReadings.isNotEmpty
      ? listReadings.first
      : forms.where((f) => f.kind == 'kana' && f.isPrimary).firstOrNull?.text ??
            forms.firstWhere((f) => f.kind == 'kana').text;

  /// How the word is shown as a question.
  late final String headword = (primaryKanji == null || usuallyKana)
      ? reading
      : primaryKanji!.text;

  List<FuriganaPart> get headwordFurigana {
    final k = primaryKanji;
    if (k == null || usuallyKana) return [FuriganaPart(reading)];
    return k.furigana ?? [FuriganaPart(k.text, reading)];
  }

  /// Readings accepted for a typed answer.
  late final List<String> acceptedReadings = {
    ...listReadings,
    for (final f in forms)
      if (f.kind == 'kana' && f.acceptAsAnswer) f.text,
  }.toList();

  /// Short meaning used in questions: the first sense.
  late final String shortMeaning = senses.isEmpty ? '' : senses.first.display;
}

class ExampleSentence {
  final String id;
  final String ja;
  final String? en;
  final String? th;
  final String jaAuthor;
  final String? enAuthor;
  final String jaLicense;
  const ExampleSentence(
    this.id,
    this.ja,
    this.en,
    this.th,
    this.jaAuthor,
    this.enAuthor,
    this.jaLicense,
  );

  /// Tatoeba sentence number, for the credit line.
  String get sourceNumber => id.startsWith('ex:') ? id.substring(3) : id;
}

/// An example sentence of a grammar point, with the part blanked in cloze
/// questions ([start], [end] count Unicode code points).
class GrammarExample {
  final ExampleSentence sentence;
  final int start;
  final int end;
  final String answer;
  final List<String> wrong;
  const GrammarExample(
    this.sentence,
    this.start,
    this.end,
    this.answer,
    this.wrong,
  );

  /// (before, answer, after), robust to offset mismatches.
  (String, String, String) get parts {
    final r = sentence.ja.runes.toList();
    if (end <= r.length &&
        String.fromCharCodes(r.sublist(start, end)) == answer) {
      return (
        String.fromCharCodes(r.sublist(0, start)),
        answer,
        String.fromCharCodes(r.sublist(end)),
      );
    }
    final i = sentence.ja.indexOf(answer);
    if (i < 0) return (sentence.ja, '', '');
    return (
      sentence.ja.substring(0, i),
      answer,
      sentence.ja.substring(i + answer.length),
    );
  }
}

class GrammarPoint {
  final String id;
  final int level;
  final int ord;
  final String titleJa;
  final String titleTh;
  final String meaningTh;
  final String formationTh;
  final String? notesTh;
  final List<String> similarIds;
  final List<GrammarExample> examples;

  const GrammarPoint({
    required this.id,
    required this.level,
    required this.ord,
    required this.titleJa,
    required this.titleTh,
    required this.meaningTh,
    required this.formationTh,
    required this.notesTh,
    required this.similarIds,
    required this.examples,
  });

  /// Examples usable as cloze questions: the Thai translation is the cue
  /// that makes exactly one option right.
  List<GrammarExample> get clozeExamples =>
      examples.where((e) => e.sentence.th?.isNotEmpty ?? false).toList();
}

class SourceCredit {
  final String id;
  final String name;
  final String homepage;
  final String license;
  final String licenseUrl;
  final String attribution;
  final String? version;
  const SourceCredit(
    this.id,
    this.name,
    this.homepage,
    this.license,
    this.licenseUrl,
    this.attribution,
    this.version,
  );
}

class ContentInfo {
  final String version;
  final int schemaVersion;
  final String? builtAt;
  final List<String> levels;
  const ContentInfo(
    this.version,
    this.schemaVersion,
    this.builtAt,
    this.levels,
  );
}

/// Read-only access to content.db. The whole file is replaced on update.
class ContentDb {
  final Database db;
  ContentDb(this.db);

  static ContentDb openFile(String path) =>
      ContentDb(sqlite3.open(path, mode: OpenMode.readOnly));

  void close() => db.close();

  ContentInfo info() {
    final m = {
      for (final r in db.select('SELECT key, value FROM meta'))
        r['key'] as String: r['value'] as String,
    };
    return ContentInfo(
      m['content_version'] ?? '0',
      int.tryParse(m['schema_version'] ?? '') ?? 0,
      m['built_at'],
      (m['levels'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
    );
  }

  List<KanaItem> kana() => [
    for (final r in db.select(
      'SELECT id, script, char, romaji, row, grp, ord FROM kana '
      "ORDER BY CASE script WHEN 'hiragana' THEN 0 ELSE 1 END, ord",
    ))
      KanaItem(
        r['id'] as String,
        r['script'] as String,
        r['char'] as String,
        r['romaji'] as String,
        r['row'] as String,
        r['grp'] as String,
        r['ord'] as int,
      ),
  ];

  List<WordItem> words() {
    final forms = <String, List<WordForm>>{};
    for (final r in db.select(
      'SELECT word_id, kind, text, furigana_json, info, is_primary, '
      'accept_as_answer FROM word_forms ORDER BY word_id, kind, ord',
    )) {
      forms
          .putIfAbsent(r.columnAt(0) as String, () => [])
          .add(
            WordForm(
              r.columnAt(1) as String,
              r.columnAt(2) as String,
              r.columnAt(3) as String?,
              r.columnAt(5) == 1,
              r.columnAt(6) == 1,
              r.columnAt(4) as String?,
            ),
          );
    }
    final senses = <String, List<Sense>>{};
    for (final r in db.select(
      'SELECT id, word_id, ord, pos, gloss_en, gloss_th, note_th, th_status '
      'FROM senses ORDER BY word_id, ord',
    )) {
      senses
          .putIfAbsent(r.columnAt(1) as String, () => [])
          .add(
            Sense(
              r.columnAt(0) as String,
              r.columnAt(2) as int,
              r.columnAt(3) as String?,
              r.columnAt(4) as String,
              r.columnAt(5) as String?,
              r.columnAt(6) as String?,
              r.columnAt(7) as String,
            ),
          );
    }
    return [
      for (final r in db.select(
        'SELECT id, jlpt_level, order_in_level, pos, tags, list_readings '
        'FROM words WHERE jlpt_level IS NOT NULL '
        'ORDER BY jlpt_level DESC, order_in_level',
      ))
        WordItem(
          id: r['id'] as String,
          level: r['jlpt_level'] as int,
          order: r['order_in_level'] as int,
          pos: _list(r['pos'] as String?),
          tags: _list(r['tags'] as String?),
          forms: forms[r['id']] ?? const [],
          senses: senses[r['id']] ?? const [],
          listReadings: _list(r['list_readings'] as String?),
        ),
    ];
  }

  List<ExampleSentence> examplesFor(String wordId, {int limit = 2}) => [
    for (final r in db.select(
      'SELECT e.id, e.ja, e.en, e.th, e.ja_author, e.en_author, '
      'e.ja_license FROM word_examples we '
      'JOIN examples e ON e.id = we.example_id '
      'WHERE we.word_id = ? ORDER BY we.rank LIMIT ?',
      [wordId, limit],
    ))
      ExampleSentence(
        r['id'] as String,
        r['ja'] as String,
        r['en'] as String?,
        r['th'] as String?,
        r['ja_author'] as String,
        r['en_author'] as String?,
        r['ja_license'] as String,
      ),
  ];

  List<GrammarPoint> grammarPoints() {
    final ex = <String, List<GrammarExample>>{};
    for (final r in db.select(
      'SELECT ge.grammar_id, ge.target_span_json, e.id, e.ja, e.en, e.th, '
      'e.ja_author, e.en_author, e.ja_license FROM grammar_examples ge '
      'JOIN examples e ON e.id = ge.example_id ORDER BY ge.grammar_id, ge.rank',
    )) {
      final span = r['target_span_json'] == null
          ? const <String, dynamic>{}
          : jsonDecode(r['target_span_json'] as String) as Map<String, dynamic>;
      final answer = span['answer'] as String?;
      if (answer == null) continue;
      ex
          .putIfAbsent(r['grammar_id'] as String, () => [])
          .add(
            GrammarExample(
              ExampleSentence(
                r['id'] as String,
                r['ja'] as String,
                r['en'] as String?,
                r['th'] as String?,
                r['ja_author'] as String,
                r['en_author'] as String?,
                r['ja_license'] as String,
              ),
              (span['start'] as num).toInt(),
              (span['end'] as num).toInt(),
              answer,
              ((span['wrong'] as List?) ?? const []).cast<String>(),
            ),
          );
    }
    return [
      for (final r in db.select(
        'SELECT * FROM grammar_points ORDER BY jlpt_level DESC, ord',
      ))
        GrammarPoint(
          id: r['id'] as String,
          level: r['jlpt_level'] as int,
          ord: r['ord'] as int,
          titleJa: r['title_ja'] as String,
          titleTh: r['title_th'] as String,
          meaningTh: r['meaning_th'] as String,
          formationTh: r['formation_th'] as String,
          notesTh: r['notes_th'] as String?,
          similarIds: _list(r['similar_ids'] as String?),
          examples: ex[r['id']] ?? const [],
        ),
    ];
  }

  List<SourceCredit> sources() => [
    for (final r in db.select(
      'SELECT id, name, homepage, license, '
      'license_url, attribution, version FROM sources ORDER BY name',
    ))
      SourceCredit(
        r['id'] as String,
        r['name'] as String,
        r['homepage'] as String,
        r['license'] as String,
        r['license_url'] as String,
        r['attribution'] as String,
        r['version'] as String?,
      ),
  ];

  /// Old id → new id (null = removed) for items dropped in this version.
  Map<String, String?> deprecations() => {
    for (final r in db.select('SELECT old_id, new_id FROM deprecations'))
      r['old_id'] as String: r['new_id'] as String?,
  };

  static List<String> _list(String? json) => json == null || json.isEmpty
      ? const []
      : (jsonDecode(json) as List).cast<String>();

  static List<FuriganaPart>? _furigana(String? json) {
    if (json == null || json.isEmpty) return null;
    return [
      for (final p in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        FuriganaPart(p['ruby'] as String, p['rt'] as String?),
    ];
  }
}

/// Checks a candidate content.db before it replaces the current one.
/// Returns a list of problems (empty = ok).
List<String> validateContentDb(String path) {
  final problems = <String>[];
  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final ok = db.select('PRAGMA quick_check').first.columnAt(0);
    if (ok != 'ok') problems.add('ไฟล์เสียหาย ($ok)');
    final tables = {
      for (final r in db.select(
        "SELECT name FROM sqlite_master WHERE type='table'",
      ))
        r['name'] as String,
    };
    for (final t in const [
      'meta',
      'sources',
      'words',
      'word_forms',
      'senses',
      'examples',
      'kana',
    ]) {
      if (!tables.contains(t)) problems.add('ไม่มีตาราง $t');
    }
    if (problems.isNotEmpty) return problems;
    final c = ContentDb(db).info();
    if (c.schemaVersion != supportedContentSchema) {
      problems.add(
        'รูปแบบเนื้อหาเวอร์ชัน ${c.schemaVersion} '
        'แอปนี้รองรับเวอร์ชัน $supportedContentSchema',
      );
    }
    final noCredit =
        db
                .select(
                  "SELECT count(*) FROM sources WHERE "
                  "attribution = '' OR license = '' OR license_url = ''",
                )
                .first
                .columnAt(0)
            as int;
    final sources =
        db.select('SELECT count(*) FROM sources').first.columnAt(0) as int;
    if (sources == 0 || noCredit > 0) problems.add('ข้อมูลเครดิตไม่ครบ');
    final noAuthor =
        db
                .select(
                  "SELECT count(*) FROM examples "
                  "WHERE ja_author IS NULL OR ja_author = ''",
                )
                .first
                .columnAt(0)
            as int;
    if (noAuthor > 0) {
      problems.add('ประโยคตัวอย่างไม่มีชื่อผู้เขียน $noAuthor ประโยค');
    }
  } on SqliteException catch (e) {
    problems.add('เปิดไฟล์ไม่ได้: ${e.message}');
  } finally {
    db?.close();
  }
  return problems;
}

/// Compares versions like "2026.09.30" or "2026.10.1" numerically.
int compareVersions(String a, String b) {
  final pa = a
      .split(RegExp(r'[.\-]'))
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pb = b
      .split(RegExp(r'[.\-]'))
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
