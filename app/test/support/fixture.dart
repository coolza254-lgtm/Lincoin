import 'dart:convert';
import 'dart:io';

import 'package:lincoin/data/catalog.dart';
import 'package:lincoin/data/content_db.dart';
import 'package:sqlite3/sqlite3.dart';

/// Schema shared with the content builder, so app and builder cannot drift.
String contentSchema() =>
    File('../tools/content_builder/lincoin_content/schema.sql')
        .readAsStringSync();

/// A tiny content.db: 3 kana and 6 N5 words (two share a meaning).
Database fixtureContentDb({String version = '2026.09.30'}) {
  final db = sqlite3.openInMemory();
  db.execute(contentSchema());
  fillFixture(db, version: version);
  return db;
}

void fillFixture(Database db, {String version = '2026.09.30'}) {
  for (final (k, v) in [
    ('schema_version', '1'),
    ('content_version', version),
    ('built_at', '2026-09-30T00:00:00+00:00'),
    ('levels', 'n5'),
  ]) {
    db.execute('INSERT INTO meta VALUES (?, ?)', [k, v]);
  }
  for (final id in ['jmdict', 'tatoeba', 'lincoin', 'jlpt']) {
    db.execute('INSERT INTO sources VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
      id,
      'Source $id',
      'https://example.org/$id',
      'CC BY-SA 4.0',
      'https://creativecommons.org/licenses/by-sa/4.0/',
      'Credit $id',
      '1',
      '[]',
    ]);
  }
  final kana = [('a', 'あ', 'a'), ('i', 'い', 'i'), ('ka', 'か', 'ka')];
  for (var i = 0; i < kana.length; i++) {
    final (id, ch, ro) = kana[i];
    db.execute('INSERT INTO kana VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
      'k:hira.$id',
      'hiragana',
      ch,
      ro,
      'a',
      'basic',
      i,
      'lincoin',
    ]);
  }
  // (seq, kanji, reading, pos, en, th, tags)
  final words = [
    (1, '秋', 'あき', 'n', 'autumn', 'ฤดูใบไม้ร่วง', <String>[]),
    (2, '足', 'あし', 'n', 'foot; leg', 'เท้า, ขา', <String>[]),
    (3, '食べる', 'たべる', 'v1', 'to eat', 'กิน', <String>[]),
    (4, '飲む', 'のむ', 'v5m', 'to drink', 'ดื่ม', <String>[]),
    (5, '私', 'わたし', 'pn', 'I; me', 'ฉัน', <String>[]),
    (6, '僕', 'ぼく', 'pn', 'I (male)', 'ฉัน', <String>[]),
    (7, null, 'コーヒー', 'n', 'coffee', 'กาแฟ', <String>[]),
  ];
  for (var i = 0; i < words.length; i++) {
    final (seq, kanji, reading, pos, en, th, tags) = words[i];
    final id = 'w:$seq';
    db.execute('INSERT INTO words VALUES (?, 5, ?, ?, ?, 1, 1, ?, ?, ?, ?)', [
      id,
      i,
      jsonEncode([pos]),
      jsonEncode(['common', ...tags]),
      'jmdict',
      'jlpt',
      en,
      jsonEncode([reading]),
    ]);
    db.execute(
      'INSERT INTO word_forms VALUES (?, ?, 0, ?, ?, NULL, ?, 1, 1, 1)',
      [id, 'kana', reading, null, '[]'],
    );
    if (kanji != null) {
      db.execute(
        'INSERT INTO word_forms VALUES (?, ?, 0, ?, ?, NULL, ?, 1, 1, 0)',
        [
          id,
          'kanji',
          kanji,
          jsonEncode([
            {'ruby': kanji, 'rt': reading},
          ]),
          '[]',
        ],
      );
    }
    db.execute(
      'INSERT INTO senses VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, NULL, ?, 1)',
      [
        '$id:1',
        id,
        jsonEncode([pos]),
        '[]',
        '[]',
        '[]',
        '[]',
        en,
        th,
        'auto_checked',
      ],
    );
  }
  db.execute('INSERT INTO examples VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)', [
    'ex:1',
    '秋が好きです。',
    'I like autumn.',
    'ฉันชอบฤดูใบไม้ร่วง',
    'someone',
    'other',
    'CC BY 2.0 FR',
    'CC BY 2.0 FR',
    'tatoeba',
  ]);
  db.execute('INSERT INTO word_examples VALUES (?, ?, 1, 1)', ['w:1', 'ex:1']);

  // Grammar: two points with translated examples, one without (not usable).
  for (final (id, ja, th) in [
    ('ex:2', 'コーヒーを飲みます。', 'ฉันดื่มกาแฟ'),
    ('ex:3', '水を飲みました。', 'ดื่มน้ำแล้ว'),
    ('ex:4', '本を読みます。', null),
  ]) {
    db.execute(
      'INSERT INTO examples VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        ja,
        'en',
        th,
        'someone',
        'other',
        'CC BY 2.0 FR',
        'CC BY 2.0 FR',
        'tatoeba',
      ],
    );
  }
  for (final (i, id, title) in [
    (1, 'g:n5.001', '〜を'),
    (2, 'g:n5.002', '〜が好きです'),
    (3, 'g:n5.003', '〜ます'),
  ]) {
    db.execute(
      'INSERT INTO grammar_points VALUES (?, 5, ?, ?, ?, ?, ?, NULL, ?, ?, ?)',
      [
        id,
        i,
        title,
        'หัวข้อ $i',
        'ความหมาย',
        'วิธีใช้',
        '[]',
        'auto_checked',
        'lincoin',
      ],
    );
  }
  String span(int start, int end, String answer, List<String> wrong) =>
      jsonEncode({
        'start': start,
        'end': end,
        'answer': answer,
        'wrong': wrong,
      });
  db.execute('INSERT INTO grammar_examples VALUES (?, ?, 0, ?)', [
    'g:n5.001',
    'ex:2',
    span(4, 5, 'を', ['に', 'で', 'の']),
  ]);
  db.execute('INSERT INTO grammar_examples VALUES (?, ?, 1, ?)', [
    'g:n5.001',
    'ex:3',
    span(1, 2, 'を', ['に', 'で', 'の']),
  ]);
  db.execute('INSERT INTO grammar_examples VALUES (?, ?, 0, ?)', [
    'g:n5.002',
    'ex:1',
    span(1, 2, 'が', ['を', 'で', 'へ']),
  ]);
  db.execute('INSERT INTO grammar_examples VALUES (?, ?, 0, ?)', [
    'g:n5.003',
    'ex:4',
    span(4, 6, 'ます', ['ません', 'ました']),
  ]);
}

Catalog fixtureCatalog() => Catalog.load(ContentDb(fixtureContentDb()));

/// Writes the fixture to a file (for validation / swap tests).
String fixtureContentFile(String dir, {String version = '2026.09.30'}) {
  final path = '$dir/content-$version.db';
  if (File(path).existsSync()) File(path).deleteSync();
  final db = sqlite3.open(path);
  db.execute(contentSchema());
  fillFixture(db, version: version);
  db.close();
  return path;
}
