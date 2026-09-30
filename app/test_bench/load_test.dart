import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lincoin/data/content_db.dart';

void main() {
  test('load breakdown', () {
    final path = Platform.environment['BENCH_CONTENT']!;
    final c = ContentDb.openFile(path);
    for (var run = 0; run < 3; run++) {
      final sw = Stopwatch()..start();
      final a = c.db.select(
        'SELECT word_id, kind, text, furigana_json, info, is_primary, accept_as_answer FROM word_forms ORDER BY word_id, kind, ord',
      );
      final t1 = sw.elapsedMicroseconds;
      var n = 0;
      for (final r in a) {
        n += (r['word_id'] as String).length + (r['text'] as String).length;
      }
      final t2 = sw.elapsedMicroseconds;
      for (final r in a) {
        final f = r['furigana_json'] as String?;
        if (f != null && f.isNotEmpty) n += (jsonDecode(f) as List).length;
        final i = r['info'] as String?;
        if (i != null && i.isNotEmpty) n += (jsonDecode(i) as List).length;
      }
      final t3 = sw.elapsedMicroseconds;
      final s = c.db.select(
        'SELECT id, word_id, ord, pos, gloss_en, gloss_th, note_th, th_status FROM senses ORDER BY word_id, ord',
      );
      final t4 = sw.elapsedMicroseconds;
      final w = c.words();
      final t5 = sw.elapsedMicroseconds;
      final g = c.grammarPoints();
      final t6 = sw.elapsedMicroseconds;
      final k = c.kana();
      final t7 = sw.elapsedMicroseconds;
      // ignore: avoid_print
      print(
        'forms select ${t1}us, access ${t2 - t1}us, json ${t3 - t2}us, senses select ${t4 - t3}us, words() ${t5 - t4}us, grammar ${t6 - t5}us, kana ${t7 - t6}us  ($n ${s.length} ${w.length} ${g.length} ${k.length})',
      );
    }
  });
}
