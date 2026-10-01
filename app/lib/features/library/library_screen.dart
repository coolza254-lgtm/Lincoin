import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../services/library_service.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../home/home_screen.dart' show levelName;
import 'word_progress_screen.dart';

/// All words and kana with their progress; search by kanji, kana, romaji
/// or meaning, narrowed by level and status.
class LibraryScreen extends ConsumerStatefulWidget {
  /// Level to show first ('n5' …); null for all.
  final String? level;
  const LibraryScreen({super.key, this.level});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  late String? _level = widget.level;
  WordProgress? _progress;
  bool _dueOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final lib = ref.watch(libraryProvider);
    final levels = ref.watch(levelProgressProvider);
    final query = _search.text;
    final all = lib?.entries() ?? const <LibraryEntry>[];
    var shown = all
        .where(
          (e) =>
              (_level == null || e.item.level == _level) &&
              (_progress == null || e.progress == _progress) &&
              (!_dueOnly || e.due) &&
              LibraryService.matches(e.item, query),
        )
        .toList();
    if (query.trim().isNotEmpty) {
      // Exact hits first; otherwise path order (List.sort is not stable).
      final exact = [
        for (final e in shown)
          if (LibraryService.rank(e.item, query) == 0) e,
      ];
      shown = [
        ...exact,
        for (final e in shown)
          if (LibraryService.rank(e.item, query) != 0) e,
      ];
    }

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: LcTokens.spacingSm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(onTap),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.library)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingLg,
                0,
                LcTokens.spacingLg,
                LcTokens.spacingSm,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t.librarySearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t.close,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: LcTokens.spacingLg,
              ),
              child: Row(
                children: [
                  chip(t.libraryAll, _level == null, () => _level = null),
                  for (final l in vocabLevels)
                    if ((levels[l]?.total ?? 0) > 0)
                      chip(levelName(t, l), _level == l, () => _level = l),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingLg,
                LcTokens.spacingXs,
                LcTokens.spacingLg,
                0,
              ),
              child: Row(
                children: [
                  chip(
                    t.libraryAll,
                    _progress == null && !_dueOnly,
                    () => (_progress = null, _dueOnly = false),
                  ),
                  chip(
                    t.libraryDue,
                    _dueOnly,
                    () => (_dueOnly = !_dueOnly, _progress = null),
                  ),
                  for (final p in WordProgress.values)
                    chip(
                      progressLabel(t, p),
                      _progress == p,
                      () => (_progress = p, _dueOnly = false),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingXl,
                LcTokens.spacingSm,
                LcTokens.spacingXl,
                LcTokens.spacingXs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(t.libraryCount(shown.length), style: tt.bodySmall),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: t.libraryEmpty,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: LcTokens.spacingXxl,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => LibraryRow(shown[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String progressLabel(AppLocalizations t, WordProgress p) => switch (p) {
  WordProgress.notStarted => t.progNotStarted,
  WordProgress.learning => t.progLearning,
  WordProgress.relearning => t.progRelearning,
  WordProgress.review => t.progReview,
  WordProgress.mastered => t.progMastered,
};

/// Foreground and background colour of a progress state.
(Color, Color) progressColors(LcPalette c, WordProgress p) => switch (p) {
  WordProgress.notStarted => (c.muted, c.track),
  WordProgress.learning => (c.accent, c.accentSoft),
  WordProgress.relearning => (c.warn, c.warnSoft),
  WordProgress.review => (c.coin, c.coinSoft),
  WordProgress.mastered => (c.good, c.goodSoft),
};

class LibraryRow extends StatelessWidget {
  final LibraryEntry e;
  const LibraryRow(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final (head, reading, meaning) = switch (e.item) {
      WordStudy(:final word) => (
        word.headword,
        word.headword == word.reading ? '' : word.reading,
        word.shortMeaning,
      ),
      KanaStudy(:final kana) => (kana.char, '', kana.romaji),
      GrammarStudy() => ('', '', ''),
    };
    final (fg, bg) = progressColors(c, e.progress);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordProgressScreen(itemId: e.item.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LcTokens.spacingXl,
          vertical: LcTokens.spacingMd,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                head,
                style: jpStyle(22, 600, c.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: LcTokens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meaning,
                    style: tt.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      if (reading.isNotEmpty) reading,
                      levelName(t, e.item.level),
                    ].join(' · '),
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: LcTokens.spacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LcPill(progressLabel(t, e.progress), bg: bg, fg: fg),
                if (e.recall != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(e.recall! * 100).round()}%',
                      style: tt.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
