import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/input.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import 'song_edit_screen.dart';
import 'song_screen.dart';

/// Tab: the song notebook, the learner's own lyrics to read and translate.
class SongsScreen extends ConsumerWidget {
  const SongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    ref.watch(dataVersionProvider);
    final songs = ref.watch(songRepoProvider).songs();
    Future<void> add() async {
      final id = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const SongEditScreen()));
      if (id != null && context.mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => SongScreen(songId: id)));
      }
    }

    return SafeArea(
      child: ListView(
        key: const PageStorageKey('songs'),
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Row(
            children: [
              Expanded(child: Text(t.songsTitle, style: tt.headlineMedium)),
              PressFilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add_rounded),
                label: Text(t.songAdd),
              ),
            ],
          ),
          const SizedBox(height: LcTokens.spacingLg),
          if (songs.isEmpty)
            LcCard(
              child: EmptyState(
                icon: Icons.library_music_rounded,
                title: t.songsEmptyTitle,
                body: t.songsEmptyBody,
              ),
            )
          else
            for (final s in songs) _SongCard(s),
        ],
      ),
    );
  }
}

class _SongCard extends ConsumerWidget {
  final Song song;
  const _SongCard(this.song);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final stats = songStats(ref, song);
    return Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
      child: LcCard(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SongScreen(songId: song.id))),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(LcTokens.radiusControl),
              ),
              child: Icon(Icons.music_note_rounded, color: c.accent),
            ),
            const SizedBox(width: LcTokens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: tt.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((song.artist ?? '').isNotEmpty)
                    Text(song.artist!, style: tt.bodySmall),
                  const SizedBox(height: 6),
                  LcProgressBar(
                    stats.lines == 0 ? 0 : stats.translated / stats.lines,
                    height: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.songStats(
                      stats.translated,
                      stats.lines,
                      (stats.knownShare * 100).round(),
                    ),
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
