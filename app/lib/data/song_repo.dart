import 'user_db.dart';

class Song {
  final String id;
  final String title;
  final String? artist;
  final String lyrics;
  final DateTime updatedAt;
  const Song(this.id, this.title, this.artist, this.lyrics, this.updatedAt);

  /// Lines that hold words (blank lines only separate verses).
  List<String> get lines => [
    for (final l in lyrics.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
}

/// A meaning the learner wrote for a word outside the content.
class MyWord {
  final String surface;
  final String? reading;
  final String meaning;
  const MyWord(this.surface, this.reading, this.meaning);
}

/// The song notebook: lyrics the learner pasted, their translations, their
/// own word meanings, and words they asked to learn first. Stays on the
/// phone (and in backups) only.
class SongRepo {
  final UserDb u;
  SongRepo(this.u);

  static int _ms(DateTime t) => t.toUtc().millisecondsSinceEpoch;

  List<Song> songs() => [
    for (final r in u.db.select(
      'SELECT id, title, artist, lyrics, updated_at FROM songs '
      'ORDER BY updated_at DESC',
    ))
      Song(
        r['id'] as String,
        r['title'] as String,
        r['artist'] as String?,
        r['lyrics'] as String,
        DateTime.fromMillisecondsSinceEpoch(
          r['updated_at'] as int,
          isUtc: true,
        ),
      ),
  ];

  Song? song(String id) => songs().where((s) => s.id == id).firstOrNull;

  /// Creates ([id] null) or updates a song; returns its id.
  String save({
    String? id,
    required String title,
    String? artist,
    required String lyrics,
    required DateTime now,
  }) {
    final songId = id ?? UserDb.newId();
    u.db.execute(
      'INSERT INTO songs(id, title, artist, lyrics, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
      'title = excluded.title, artist = excluded.artist, '
      'lyrics = excluded.lyrics, updated_at = excluded.updated_at',
      [songId, title, artist, lyrics, _ms(now), _ms(now)],
    );
    return songId;
  }

  void delete(String id) => u.tx(() {
    u.db.execute('DELETE FROM song_lines WHERE song_id = ?', [id]);
    u.db.execute('DELETE FROM songs WHERE id = ?', [id]);
  });

  /// The learner's translation of each line of [songId], by line text.
  Map<String, String> translations(String songId) => {
    for (final r in u.db.select(
      'SELECT line, translation FROM song_lines WHERE song_id = ?',
      [songId],
    ))
      r['line'] as String: r['translation'] as String,
  };

  void setTranslation(String songId, String line, String text, DateTime now) {
    if (text.trim().isEmpty) {
      u.db.execute('DELETE FROM song_lines WHERE song_id = ? AND line = ?', [
        songId,
        line,
      ]);
      return;
    }
    u.db.execute(
      'INSERT OR REPLACE INTO song_lines(song_id, line, translation, '
      'updated_at) VALUES (?, ?, ?, ?)',
      [songId, line, text, _ms(now)],
    );
    u.db.execute('UPDATE songs SET updated_at = ? WHERE id = ?', [
      _ms(now),
      songId,
    ]);
  }

  Map<String, MyWord> myWords() => {
    for (final r in u.db.select(
      'SELECT surface, reading, meaning FROM my_words',
    ))
      r['surface'] as String: MyWord(
        r['surface'] as String,
        r['reading'] as String?,
        r['meaning'] as String,
      ),
  };

  void setMyWord(
    String surface,
    String? reading,
    String meaning,
    DateTime now,
  ) {
    if (meaning.trim().isEmpty) {
      u.db.execute('DELETE FROM my_words WHERE surface = ?', [surface]);
      return;
    }
    u.db.execute(
      'INSERT OR REPLACE INTO my_words(surface, reading, meaning, updated_at) '
      'VALUES (?, ?, ?, ?)',
      [surface, reading, meaning, _ms(now)],
    );
  }

  /// Items to introduce before the rest of the path, oldest request first.
  List<String> priorityItems() => [
    for (final r in u.db.select(
      'SELECT item_id FROM priority_items ORDER BY added_at, rowid',
    ))
      r['item_id'] as String,
  ];

  void addPriority(Iterable<String> itemIds, String source, DateTime now) =>
      u.tx(() {
        for (final id in itemIds) {
          u.db.execute(
            'INSERT OR IGNORE INTO priority_items(item_id, added_at, source) '
            'VALUES (?, ?, ?)',
            [id, _ms(now), source],
          );
        }
      });
}
