import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../data/content_db.dart';
import '../../data/song_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../services/library_service.dart';
import '../../services/lyrics.dart';
import '../../state/providers.dart';
import '../../ui/input.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../library/library_screen.dart' show progressColors, progressLabel;
import '../library/word_progress_screen.dart';
import '../study/item_details.dart';
import 'song_edit_screen.dart';

/// Translated lines, total lines and the share of the song's vocabulary
/// the learner already knows.
({int translated, int lines, double knownShare, List<String> newItems})
songStats(WidgetRef ref, Song song) {
  final tok = ref.watch(lyricsTokenizerProvider);
  final lib = ref.watch(libraryProvider);
  final done = ref.watch(songRepoProvider).translations(song.id);
  final lines = song.lines;
  final words = <String, WordStudy>{};
  if (tok != null) {
    for (final l in lines) {
      for (final t in tok.tokenize(l)) {
        if (t.word != null) words[t.word!.id] = t.word!;
      }
    }
  }
  var known = 0;
  final fresh = <String>[];
  for (final id in words.keys) {
    final p = lib?.entry(id)?.progress;
    if (p == WordProgress.review || p == WordProgress.mastered) known++;
    if (p == null || p == WordProgress.notStarted) fresh.add(id);
  }
  return (
    translated: lines.where(done.containsKey).length,
    lines: lines.length,
    knownShare: words.isEmpty ? 0 : known / words.length,
    newItems: fresh,
  );
}

/// Ruby for a word as it appears in the song: the reading goes over the
/// kanji stem and the kana ending (okurigana, conjugation) stays plain.
List<FuriganaPart> rubyFor(String surface, WordStudy w) {
  bool hasKanji(String s) => s.runes.any((c) => c >= 0x3400 && c <= 0x9FFF);
  if (!hasKanji(surface)) return [FuriganaPart(surface)];
  final reading = w.word.reading;
  for (final f in w.word.forms.where((f) => f.kind == 'kanji')) {
    var k = 0;
    while (k < f.text.length &&
        k < reading.length &&
        f.text[f.text.length - 1 - k] == reading[reading.length - 1 - k]) {
      k++;
    }
    final stem = f.text.substring(0, f.text.length - k);
    final rStem = reading.substring(0, reading.length - k);
    if (stem.isNotEmpty && surface.startsWith(stem)) {
      return [
        FuriganaPart(stem, rStem),
        if (surface.length > stem.length)
          FuriganaPart(surface.substring(stem.length)),
      ];
    }
  }
  return [FuriganaPart(surface)];
}

String inflectionLabel(AppLocalizations t, Inflection i) => switch (i) {
  Inflection.polite => t.infPolite,
  Inflection.past => t.infPast,
  Inflection.te => t.infTe,
  Inflection.negative => t.infNegative,
  Inflection.want => t.infWant,
  Inflection.passive => t.infPassive,
  Inflection.causative => t.infCausative,
  Inflection.potential => t.infPotential,
  Inflection.volitional => t.infVolitional,
  Inflection.conditional => t.infConditional,
  Inflection.imperative => t.infImperative,
  Inflection.adverb => t.infAdverb,
  Inflection.continuing => t.infContinuing,
};

/// Reads one song: every word can be tapped for its meaning, and each line
/// has a field for the learner's own translation.
class SongScreen extends ConsumerStatefulWidget {
  final String songId;
  const SongScreen({super.key, required this.songId});

  @override
  ConsumerState<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends ConsumerState<SongScreen> {
  bool _furigana = true;
  bool _hideMine = false;
  final Set<int> _revealed = {};

  Future<void> _learnNew(List<String> ids) async {
    final t = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    if (ids.isEmpty) {
      m.showSnackBar(SnackBar(content: Text(t.songNoNewWords)));
      return;
    }
    ref
        .read(songRepoProvider)
        .addPriority(ids, 'song:${widget.songId}', DateTime.now().toUtc());
    ref.read(dataVersionProvider.notifier).bump();
    m.showSnackBar(SnackBar(content: Text(t.songNewWordsAdded(ids.length))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    ref.watch(dataVersionProvider);
    final repo = ref.watch(songRepoProvider);
    final song = repo.song(widget.songId);
    final tok = ref.watch(lyricsTokenizerProvider);
    if (song == null || tok == null) {
      return Scaffold(appBar: AppBar());
    }
    final stats = songStats(ref, song);
    final queued = repo.priorityItems().toSet();
    final fresh = stats.newItems.where((id) => !queued.contains(id)).toList();
    final mine = repo.translations(song.id);
    final lines = song.lines;
    return Scaffold(
      appBar: AppBar(
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: t.songFurigana,
            isSelected: _furigana,
            icon: const Icon(Icons.text_fields_rounded),
            selectedIcon: const Icon(Icons.text_format_rounded),
            onPressed: () => setState(() => _furigana = !_furigana),
          ),
          IconButton(
            tooltip: _hideMine ? t.songShowMine : t.songHideMine,
            isSelected: _hideMine,
            icon: const Icon(Icons.visibility_rounded),
            selectedIcon: const Icon(Icons.visibility_off_rounded),
            onPressed: () => setState(() {
              _hideMine = !_hideMine;
              _revealed.clear();
            }),
          ),
          IconButton(
            tooltip: t.songEdit,
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SongEditScreen(songId: song.id),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingLg,
            0,
            LcTokens.spacingLg,
            LcTokens.spacingXxl,
          ),
          itemCount: lines.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
                child: LcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if ((song.artist ?? '').isNotEmpty)
                        Text(song.artist!, style: tt.bodyMedium),
                      Text(
                        t.songStats(
                          stats.translated,
                          stats.lines,
                          (stats.knownShare * 100).round(),
                        ),
                        style: tt.bodySmall,
                      ),
                      const SizedBox(height: LcTokens.spacingSm),
                      LcProgressBar(
                        stats.lines == 0 ? 0 : stats.translated / stats.lines,
                        height: 6,
                      ),
                      const SizedBox(height: LcTokens.spacingMd),
                      Wrap(
                        spacing: LcTokens.spacingMd,
                        runSpacing: 4,
                        children: [
                          _Legend(c.accent, t.songLegendNew),
                          _Legend(c.coin, t.songLegendLearning),
                          _Legend(Colors.transparent, t.songLegendKnown),
                          _Legend(c.line, t.songLegendOutside, dotted: true),
                        ],
                      ),
                      const SizedBox(height: LcTokens.spacingMd),
                      PressOutlinedButton.icon(
                        onPressed: () => _learnNew(fresh),
                        icon: const Icon(Icons.style_rounded),
                        label: Text(t.songNewWords(fresh.length)),
                      ),
                    ],
                  ),
                ),
              );
            }
            final line = lines[i - 1];
            return _Line(
              key: ValueKey('line-$i'),
              songId: song.id,
              line: line,
              tokens: tok.tokenize(line),
              furigana: _furigana,
              translation: mine[line],
              hidden: _hideMine && !_revealed.contains(i),
              onReveal: () => setState(() => _revealed.add(i)),
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dotted;
  const _Legend(this.color, this.label, {this.dotted = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          color: dotted ? null : color,
          border: dotted ? Border(bottom: BorderSide(color: color)) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// One lyric line: tappable words, a speaker, and the learner's translation.
class _Line extends ConsumerStatefulWidget {
  final String songId;
  final String line;
  final List<LyricToken> tokens;
  final bool furigana;
  final String? translation;
  final bool hidden;
  final VoidCallback onReveal;
  const _Line({
    super.key,
    required this.songId,
    required this.line,
    required this.tokens,
    required this.furigana,
    required this.translation,
    required this.hidden,
    required this.onReveal,
  });

  @override
  ConsumerState<_Line> createState() => _LineState();
}

class _LineState extends ConsumerState<_Line> {
  late final _ctl = TextEditingController(text: widget.translation ?? '');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save(String v) => ref
      .read(songRepoProvider)
      .setTranslation(widget.songId, widget.line, v, DateTime.now().toUtc());

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final lib = ref.watch(libraryProvider);
    final my = ref.watch(songRepoProvider).myWords();
    return Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    for (final tk in widget.tokens)
                      _Token(
                        tk,
                        furigana: widget.furigana,
                        progress: tk.word == null
                            ? null
                            : lib?.entry(tk.word!.id)?.progress,
                        mine: my[tk.text],
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.songReadLine,
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                color: c.muted,
                icon: const Icon(Icons.volume_up_rounded),
                onPressed: () => ref.read(ttsProvider).speak(widget.line),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.hidden)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: Text(
                  (widget.translation ?? '').isEmpty
                      ? t.songNoTranslation
                      : t.songTapToReveal,
                ),
                onPressed: widget.onReveal,
              ),
            )
          else
            TextField(
              controller: _ctl,
              onChanged: _save,
              maxLines: null,
              style: tt.bodyLarge,
              decoration: InputDecoration(
                hintText: t.songTranslateHint,
                isDense: true,
                filled: true,
                fillColor: c.surface,
              ),
            ),
        ],
      ),
    );
  }
}

class _Token extends StatelessWidget {
  final LyricToken token;
  final bool furigana;
  final WordProgress? progress;
  final MyWord? mine;
  const _Token(
    this.token, {
    required this.furigana,
    required this.progress,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final style = jpStyle(24, 600, c.ink);
    if (token.isGap) {
      return Text(token.text, style: style);
    }
    final w = token.word;
    final (Color line, bool dotted) = switch (progress) {
      _ when w == null && token.grammar != null => (Colors.transparent, false),
      _ when w == null => (mine != null ? c.muted : c.line, true),
      // Known words carry no line, so the eye goes to what is left.
      WordProgress.review ||
      WordProgress.mastered => (Colors.transparent, false),
      WordProgress.learning || WordProgress.relearning => (c.coin, false),
      _ => (c.accent, false),
    };
    final parts = w != null && furigana
        ? rubyFor(token.text, w)
        : [
            FuriganaPart(
              token.text,
              furigana && mine?.reading != null ? mine!.reading : null,
            ),
          ];
    return Semantics(
      button: true,
      label: token.text,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showLyricWord(context, token),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: line,
                width: dotted ? 1.5 : 3,
                style: BorderStyle.solid,
              ),
            ),
          ),
          child: Furigana(parts, size: 24, weight: 600, showReading: furigana),
        ),
      ),
    );
  }
}

/// What a tapped word means: dictionary entry (with how it was conjugated),
/// a grammar note, or the learner's own note for words outside the content.
Future<void> showLyricWord(BuildContext context, LyricToken token) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scroll) => _WordSheet(token, scroll),
      ),
    );

class _WordSheet extends ConsumerStatefulWidget {
  final LyricToken token;
  final ScrollController scroll;
  const _WordSheet(this.token, this.scroll);

  @override
  ConsumerState<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<_WordSheet> {
  final _reading = TextEditingController();
  final _meaning = TextEditingController();

  @override
  void initState() {
    super.initState();
    final mine = ref.read(songRepoProvider).myWords()[widget.token.text];
    _reading.text = mine?.reading ?? '';
    _meaning.text = mine?.meaning ?? '';
  }

  @override
  void dispose() {
    _reading.dispose();
    _meaning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final tk = widget.token;
    final w = tk.word;
    final lib = ref.watch(libraryProvider);
    ref.watch(dataVersionProvider);
    final queued = ref.watch(songRepoProvider).priorityItems().toSet();
    final entry = w == null ? null : lib?.entry(w.id);
    final children = <Widget>[
      Row(
        children: [
          Expanded(child: Text(tk.text, style: jpStyle(34, 700, c.ink))),
          IconButton(
            tooltip: t.listen,
            color: c.accent,
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => ref.read(ttsProvider).speak(tk.text),
          ),
        ],
      ),
      if (w != null && tk.steps.isNotEmpty) ...[
        Text(t.wordDictForm(w.word.headword), style: tt.bodyLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: LcTokens.spacingSm,
          runSpacing: 4,
          children: [
            for (final s in tk.steps)
              LcPill(inflectionLabel(t, s), bg: c.track, fg: c.ink),
          ],
        ),
      ],
      const SizedBox(height: LcTokens.spacingMd),
    ];
    if (w != null) {
      final p = entry?.progress ?? WordProgress.notStarted;
      final (fg, bg) = progressColors(c, p);
      final inQueue = queued.contains(w.id) && p == WordProgress.notStarted;
      children.addAll([
        LcCard(child: ItemDetails(item: w)),
        const SizedBox(height: LcTokens.spacingMd),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: LcTokens.spacingSm,
          runSpacing: LcTokens.spacingSm,
          children: [
            LcPill(progressLabel(t, p), bg: bg, fg: fg),
            if (p == WordProgress.notStarted)
              PressFilledButton.icon(
                onPressed: inQueue
                    ? null
                    : () {
                        ref
                            .read(songRepoProvider)
                            .addPriority(
                              [w.id],
                              'song',
                              DateTime.now().toUtc(),
                            );
                        ref.read(dataVersionProvider.notifier).bump();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.wordAddedToCards)),
                        );
                      },
                icon: Icon(inQueue ? Icons.check_rounded : Icons.add_rounded),
                label: Text(inQueue ? t.wordQueued : t.wordAddToCards),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: Text(t.wordProgressOpen),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WordProgressScreen(itemId: w.id),
                  ),
                ),
              ),
          ],
        ),
      ]);
    } else if (tk.grammar != null) {
      children.addAll([
        LcPill(t.wordGrammar, bg: c.accentSoft, fg: c.accent),
        const SizedBox(height: LcTokens.spacingSm),
        Text(tk.grammar!, style: tt.titleMedium),
      ]);
    } else {
      children.addAll([
        LcPill(t.wordOutside, bg: c.track, fg: c.muted),
        const SizedBox(height: LcTokens.spacingLg),
        Text(t.wordMyMeaning, style: tt.titleMedium),
        const SizedBox(height: LcTokens.spacingSm),
        TextField(
          controller: _reading,
          style: jpStyle(18, 500, c.ink),
          decoration: InputDecoration(labelText: t.wordMyReading),
        ),
        const SizedBox(height: LcTokens.spacingSm),
        TextField(
          controller: _meaning,
          decoration: InputDecoration(
            labelText: t.wordMyMeaning,
            hintText: t.wordMyMeaningHint,
          ),
        ),
        const SizedBox(height: LcTokens.spacingMd),
        PressFilledButton(
          onPressed: () {
            ref
                .read(songRepoProvider)
                .setMyWord(
                  tk.text,
                  _reading.text.trim().isEmpty ? null : _reading.text.trim(),
                  _meaning.text.trim(),
                  DateTime.now().toUtc(),
                );
            ref.read(dataVersionProvider.notifier).bump();
            Navigator.of(context).pop();
          },
          child: Text(t.wordMySave),
        ),
      ]);
    }
    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(
        LcTokens.spacingXl,
        0,
        LcTokens.spacingXl,
        LcTokens.spacingXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: children,
    );
  }
}
